import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../models/academic_result.dart';
import '../../models/course.dart';
import '../../models/quiz_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/faculty_module_service.dart';
import 'assignment_submissions_screen.dart';

enum _FacultyTab {
  dashboard,
  courses,
  attendance,
  assignments,
  notifications,
  profile,
}

enum _ComposerMode { assignment, quiz }

class _QuizQuestionDraft {
  final TextEditingController questionCtrl = TextEditingController();
  final TextEditingController optionACtrl = TextEditingController();
  final TextEditingController optionBCtrl = TextEditingController();
  final TextEditingController optionCCtrl = TextEditingController();
  final TextEditingController optionDCtrl = TextEditingController();
  final TextEditingController answerCtrl = TextEditingController();
  final TextEditingController marksCtrl = TextEditingController(text: '1');

  void dispose() {
    questionCtrl.dispose();
    optionACtrl.dispose();
    optionBCtrl.dispose();
    optionCCtrl.dispose();
    optionDCtrl.dispose();
    answerCtrl.dispose();
    marksCtrl.dispose();
  }

  Map<String, dynamic> toMap() {
    return {
      'questionText': questionCtrl.text.trim(),
      'type': 'mcq',
      'options': [
        optionACtrl.text.trim(),
        optionBCtrl.text.trim(),
        optionCCtrl.text.trim(),
        optionDCtrl.text.trim(),
      ].where((item) => item.isNotEmpty).toList(),
      'correctAnswer': answerCtrl.text.trim(),
      'marks': int.tryParse(marksCtrl.text.trim()) ?? 1,
    };
  }
}

_FacultyTab _facultyTabFromQuery(String? tab) {
  switch ((tab ?? '').trim().toLowerCase()) {
    case 'courses':
      return _FacultyTab.courses;
    case 'attendance':
      return _FacultyTab.attendance;
    case 'assignments':
      return _FacultyTab.assignments;
    case 'notifications':
      return _FacultyTab.notifications;
    case 'profile':
      return _FacultyTab.profile;
    default:
      return _FacultyTab.dashboard;
  }
}

class FacultyDashboardScreen extends StatefulWidget {
  final String? initialTab;

  const FacultyDashboardScreen({super.key, this.initialTab});

  @override
  State<FacultyDashboardScreen> createState() => _FacultyDashboardScreenState();
}

class _FacultyDashboardScreenState extends State<FacultyDashboardScreen> {
  final FacultyModuleService _service = FacultyModuleService.instance;
  Stream<FacultyDashboardData>? _stream;
  _FacultyTab _tab = _FacultyTab.dashboard;

  @override
  void initState() {
    super.initState();
    _tab = _facultyTabFromQuery(widget.initialTab);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureLoaded();
  }

  void _ensureLoaded() {
    if (_stream != null) return;
    final auth = context.read<AuthProvider>();
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (auth.currentUser == null || firebaseUser == null) return;
    _stream = _service.watchDashboard(
      firebaseUid: firebaseUser.uid,
      userDocId: auth.currentUser!.id,
    );
  }

  Future<void> _reload() async {
    final auth = context.read<AuthProvider>();
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (auth.currentUser == null || firebaseUser == null) return;
    setState(() {
      _stream = _service.watchDashboard(
        firebaseUid: firebaseUser.uid,
        userDocId: auth.currentUser!.id,
        forceRefresh: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (auth.currentUser?.role != 'faculty') {
      return Scaffold(
        appBar: AppBar(title: const Text('Access denied')),
        body: const Center(
          child: Text('Only faculty accounts can access this module.'),
        ),
      );
    }

    if (auth.currentUser == null || firebaseUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    _ensureLoaded();
    final user = auth.currentUser!;
    final facultyProfile = auth.facultyProfile;

    return Scaffold(
      backgroundColor: AppColors.surfaceWarm,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceWarm,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryDark,
              child: Text(
                _initials(user.name),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'The Academic Curator',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
          IconButton(
            onPressed: () => auth.logout(),
            icon: const Icon(Icons.logout_outlined),
          ),
        ],
      ),
      body: StreamBuilder<FacultyDashboardData>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.danger,
                      size: 52,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _reload,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data =
              snapshot.data ??
              const FacultyDashboardData(
                courses: [],
                studentCountByCourse: {},
                assignments: [],
                quizzes: [],
                materials: [],
                announcements: [],
                pendingTasks: 0,
              );

          return _buildSelectedTab(
            data,
            user.name,
            user.email,
            facultyProfile?.department ?? '-',
            facultyProfile?.designation ?? '-',
            facultyProfile?.employeeId ?? '-',
            firebaseUser.uid,
            () => auth.logout(),
          );
        },
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _tab.index,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primaryDark,
          unselectedItemColor: AppColors.ink500,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          showUnselectedLabels: true,
          onTap: (index) => setState(() => _tab = _FacultyTab.values[index]),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_outlined),
              label: 'Courses',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.checklist_outlined),
              label: 'Attendance',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_outlined),
              label: 'Tasks',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.campaign_outlined),
              label: 'Notices',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedTab(
    FacultyDashboardData data,
    String userName,
    String userEmail,
    String department,
    String designation,
    String employeeId,
    String facultyUid,
    VoidCallback onLogout,
  ) {
    switch (_tab) {
      case _FacultyTab.dashboard:
        return _FacultyHomeTab(
          data: data,
          facultyName: userName,
          onOpenAttendance: () => setState(() => _tab = _FacultyTab.attendance),
          onOpenAssignments: () =>
              setState(() => _tab = _FacultyTab.assignments),
          onOpenNotifications: () =>
              setState(() => _tab = _FacultyTab.notifications),
        );
      case _FacultyTab.courses:
        return _FacultyCoursesTab(data: data, service: _service);
      case _FacultyTab.attendance:
        return _FacultyAttendanceTab(
          data: data,
          facultyId: facultyUid,
          service: _service,
        );
      case _FacultyTab.assignments:
        return _FacultyAssignmentsTab(
          data: data,
          facultyId: facultyUid,
          service: _service,
          onRefreshParent: _reload,
        );
      case _FacultyTab.notifications:
        return _FacultyNotificationsTab(
          data: data,
          facultyId: facultyUid,
          service: _service,
          onRefreshParent: _reload,
        );
      case _FacultyTab.profile:
        return _FacultyProfileTab(
          userName: userName,
          email: userEmail,
          department: department,
          designation: designation,
          employeeId: employeeId,
          courses: data.courses,
          onLogout: onLogout,
        );
    }
  }
}

class _FacultyHomeTab extends StatelessWidget {
  final FacultyDashboardData data;
  final String facultyName;
  final VoidCallback onOpenAttendance;
  final VoidCallback onOpenAssignments;
  final VoidCallback onOpenNotifications;

  const _FacultyHomeTab({
    required this.data,
    required this.facultyName,
    required this.onOpenAttendance,
    required this.onOpenAssignments,
    required this.onOpenNotifications,
  });

  @override
  Widget build(BuildContext context) {
    final upcoming = data.assignments.take(2).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Text(
          'IIIT NAGPUR PORTAL',
          style: TextStyle(
            color: Color(0xFF01695B),
            fontWeight: FontWeight.w700,
            letterSpacing: 1.3,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Hello, $facultyName',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Welcome back to your curriculum command center. Here is your overview for the current semester.',
          style: TextStyle(color: AppColors.ink700, height: 1.4),
        ),
        const SizedBox(height: 16),
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'COURSE MANAGEMENT',
                style: TextStyle(
                  color: AppColors.ink500,
                  letterSpacing: 1.2,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _MetricBlock(
                      value: '${data.courses.length}',
                      label: 'Total\nCourses',
                    ),
                  ),
                  Container(width: 1, height: 80, color: AppColors.border),
                  Expanded(
                    child: _MetricBlock(
                      value: '${data.pendingTasks}',
                      label: 'Live\nTasks',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Student counts are shown inside each course card only.',
                style: TextStyle(color: AppColors.ink500, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: data.courses
                    .take(3)
                    .map(
                      (course) =>
                          _TagChip(label: '${course.code} ${course.semester}'),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withOpacity(0.28),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PENDING TASKS',
                      style: TextStyle(
                        color: Colors.white70,
                        letterSpacing: 1.1,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${data.pendingTasks}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 56,
                        height: 0.95,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: onOpenAssignments,
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('View All Tasks'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.35)),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.assignment_turned_in_outlined,
                  color: Colors.white,
                  size: 42,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 34,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.05,
          children: [
            _ActionTile(
              label: 'Mark Attendance',
              subtitle: 'Daily tracking for active sessions.',
              icon: Icons.how_to_reg_outlined,
              iconColor: AppColors.primaryDark,
              onTap: onOpenAttendance,
            ),
            _ActionTile(
              label: 'Create Assignment',
              subtitle: 'Set deadlines and requirements.',
              icon: Icons.edit_note_outlined,
              iconColor: const Color(0xFF01695B),
              onTap: onOpenAssignments,
            ),
            _ActionTile(
              label: 'Upload Material',
              subtitle: 'Share PDFs and useful links.',
              icon: Icons.file_upload_outlined,
              iconColor: AppColors.primaryDark,
              onTap: onOpenAssignments,
            ),
            _ActionTile(
              label: 'Send Announcement',
              subtitle: 'Notify all student cohorts.',
              icon: Icons.campaign_outlined,
              iconColor: AppColors.danger,
              onTap: onOpenNotifications,
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Upcoming Schedule',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 34,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 12),
        ...upcoming.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ScheduleCard(
              timeLabel: DateFormat('dd').format(item.dueDate.toDate()),
              meridiem: 'AM',
              title: item.title,
              subtitle: 'Lecture hall 304 • ${item.courseId}',
              accent: AppColors.primaryDark,
            ),
          ),
        ),
        if (upcoming.isEmpty)
          _ScheduleCard(
            timeLabel: '02',
            meridiem: 'PM',
            title: 'Faculty Committee Meeting',
            subtitle: 'Conference Room B • Administrative',
            accent: const Color(0xFF01695B),
          ),
        const SizedBox(height: 14),
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Department Notice',
                style: TextStyle(
                  fontSize: 30,
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 140,
                  color: const Color(0xFFDDE8F2),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.apartment_outlined,
                    size: 54,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Annual Research Symposium abstract submission deadline extended to Friday, Oct 27th.',
                style: TextStyle(color: AppColors.ink700, height: 1.4),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onOpenNotifications,
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Read More'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FacultyCoursesTab extends StatelessWidget {
  final FacultyDashboardData data;
  final FacultyModuleService service;

  const _FacultyCoursesTab({required this.data, required this.service});

  @override
  Widget build(BuildContext context) {
    if (data.courses.isEmpty) {
      return const Center(child: Text('No faculty courses found.'));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Text(
          'FACULTY OVERVIEW • SPRING 2024',
          style: TextStyle(
            color: Color(0xFF01695B),
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'IIIT Nagpur\nAcademic Portfolio',
          style: TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w800,
            fontSize: 54,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Manage your curriculum, track student engagement, and curate course content for the ongoing semester.',
          style: TextStyle(color: AppColors.ink700, height: 1.4),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _GlassStatCard(
                title: 'ACTIVE COURSES',
                value: '${data.courses.length}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _GlassStatCard(
                title: 'LIVE TASKS',
                value: '${data.pendingTasks}',
                accent: AppColors.primaryDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...data.courses.map((course) {
          final count = data.studentCountByCourse[course.courseId] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CourseTile(
              title: course.title,
              code: course.code,
              semester: course.semester,
              students: count,
              accent: count > 90
                  ? const Color(0xFF01695B)
                  : AppColors.primaryDark,
              onUploadResults: () => _openResultsSheet(context, course),
            ),
          );
        }),
        const SizedBox(height: 8),
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'EXCLUSIVE INSIGHT',
                style: TextStyle(
                  color: Color(0xFF01695B),
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Curate your next\nresearch colloquium.',
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'The next batch of student assistants is ready for assignment.',
                style: TextStyle(color: AppColors.ink700, height: 1.4),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {},
                child: const Text('Review Applications'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openResultsSheet(
    BuildContext context,
    CourseModel course,
  ) async {
    final students = await service.fetchStudentsForCourse(course.courseId);
    if (students.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No enrolled students found for this course.'),
          ),
        );
      }
      return;
    }

    final controllers = <String, TextEditingController>{
      for (final student in students)
        student.studentId: TextEditingController(),
    };
    var saving = false;
    var sheetDismissed = false;

    Future<void> saveResults(StateSetter setSheetState) async {
      if (saving) return;
      final marksByStudent = <String, num>{};
      for (final student in students) {
        final value = int.tryParse(controllers[student.studentId]!.text.trim());
        if (value == null) {
          throw Exception('Please enter marks for ${student.name}.');
        }
        marksByStudent[student.studentId] = value.clamp(0, 100);
      }
      setSheetState(() => saving = true);
      try {
        await service.uploadResultsBatch(
          facultyId: course.facultyId,
          courseId: course.courseId,
          marksByStudent: marksByStudent,
        );
        sheetDismissed = true;
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Results published successfully.')),
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error.toString().replaceFirst('Exception: ', '')),
            ),
          );
        }
      } finally {
        if (!sheetDismissed) {
          setSheetState(() => saving = false);
        }
      }
    }

    for (final controller in controllers.values) {
      controller.text = '';
    }

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.88,
              minChildSize: 0.6,
              maxChildSize: 0.96,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      Center(
                        child: Container(
                          width: 54,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Upload Results',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink900,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${course.code} | ${course.title} | ${course.semester}',
                        style: const TextStyle(color: AppColors.ink500),
                      ),
                      const SizedBox(height: 16),
                      ...students.map(
                        (student) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceWarm,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  student.email,
                                  style: const TextStyle(
                                    color: AppColors.ink500,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: controllers[student.studentId],
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Marks out of 100',
                                    hintText: 'Enter marks',
                                  ),
                                  onChanged: (_) => setSheetState(() {}),
                                ),
                                const SizedBox(height: 8),
                                Builder(
                                  builder: (_) {
                                    final raw =
                                        int.tryParse(
                                          controllers[student.studentId]!.text
                                              .trim(),
                                        ) ??
                                        0;
                                    final grade = gradeFromMarks(
                                      raw.clamp(0, 100),
                                    );
                                    return Text(
                                      'Grade preview: $grade',
                                      style: const TextStyle(
                                        color: AppColors.primaryDark,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: saving
                            ? null
                            : () async => saveResults(setSheetState),
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.upload_outlined),
                        label: Text(
                          saving ? 'Publishing...' : 'Publish Results',
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );

    for (final controller in controllers.values) {
      controller.dispose();
    }
  }
}

class _FacultyAttendanceTab extends StatefulWidget {
  final FacultyDashboardData data;
  final String facultyId;
  final FacultyModuleService service;

  const _FacultyAttendanceTab({
    required this.data,
    required this.facultyId,
    required this.service,
  });

  @override
  State<_FacultyAttendanceTab> createState() => _FacultyAttendanceTabState();
}

class _FacultyAttendanceTabState extends State<_FacultyAttendanceTab> {
  String? _selectedCourseId;
  DateTime _selectedDate = DateTime.now();
  List<CourseStudent> _students = [];
  final Map<String, bool> _attendance = {};
  bool _loadingStudents = false;
  bool _submitting = false;

  Future<void> _loadStudents() async {
    final courseId = _selectedCourseId;
    if (courseId == null || courseId.isEmpty) return;
    setState(() => _loadingStudents = true);
    final students = await widget.service.fetchStudentsForCourse(courseId);
    setState(() {
      _students = students;
      _attendance
        ..clear()
        ..addEntries(
          students.map((student) => MapEntry(student.studentId, true)),
        );
      _loadingStudents = false;
    });
  }

  Future<void> _submit() async {
    if (_selectedCourseId == null || _students.isEmpty) return;
    setState(() => _submitting = true);
    await widget.service.submitAttendanceBatch(
      facultyId: widget.facultyId,
      courseId: _selectedCourseId!,
      date: _selectedDate,
      attendanceByStudent: _attendance,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Attendance saved successfully.')),
    );
  }

  Future<void> _downloadExcel() async {
    if (_selectedCourseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a course first.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final courseCode = widget.data.courses
          .firstWhere((c) => c.courseId == _selectedCourseId)
          .code;
      final savedPath = await widget.service.generateAttendanceExcel(
        courseId: _selectedCourseId!,
        courseCode: courseCode,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attendance Excel saved to $savedPath')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final present = _attendance.values.where((value) => value).length;
    final absent = _attendance.values.where((value) => !value).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Text(
          'ATTENDANCE SESSION',
          style: TextStyle(
            color: Color(0xFF01695B),
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Student Attendance',
          style: TextStyle(
            color: AppColors.primaryDark,
            fontSize: 54,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedCourseId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'SELECTED COURSE'),
          items: widget.data.courses
              .map(
                (course) => DropdownMenuItem<String>(
                  value: course.courseId,
                  child: Text(
                    '${course.code} | ${course.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          selectedItemBuilder: (context) => widget.data.courses
              .map(
                (course) => Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${course.code} | ${course.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() => _selectedCourseId = value);
            _loadStudents();
          },
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                initialDate: _selectedDate,
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
              }
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              alignment: Alignment.center,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_month_outlined),
                  const SizedBox(width: 8),
                  Text(
                    'Date: ${DateFormat('dd MMM yyyy').format(_selectedDate)}',
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryStrip(
                title: 'Course Strength',
                value: '${_students.length}',
                icon: Icons.groups_2_outlined,
                accent: const Color(0xFF01695B),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryStrip(
                title: 'Present Today',
                value: '$present',
                icon: Icons.how_to_reg_outlined,
                accent: AppColors.primaryDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryStrip(
                title: 'Absent Today',
                value: '$absent',
                icon: Icons.person_off_outlined,
                accent: AppColors.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Roll Call List',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: _submitting ? null : _downloadExcel,
                icon: const Icon(
                  Icons.download_rounded,
                  color: AppColors.primary,
                ),
                tooltip: 'Download Attendance Excel',
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    for (final student in _students) {
                      _attendance[student.studentId] = true;
                    }
                  });
                },
                child: const Text('MARK ALL PRESENT'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_loadingStudents)
          const Center(child: CircularProgressIndicator())
        else if (_students.isEmpty)
          const Text('Select a course to load students.')
        else
          ..._students.map(
            (student) => Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: SwitchListTile(
                title: Text(
                  student.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(student.email),
                value: _attendance[student.studentId] ?? true,
                onChanged: (value) =>
                    setState(() => _attendance[student.studentId] = value),
                activeColor: Colors.white,
                activeTrackColor: const Color(0xFF01695B),
                inactiveTrackColor: AppColors.ink100,
                secondary: CircleAvatar(
                  backgroundColor: AppColors.ink100,
                  child: Text(
                    _initials(student.name),
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        _GlassCard(
          child: const Text(
            'Curator Insight\nAttendance today is higher than weekly average for this course.',
            style: TextStyle(
              color: AppColors.primaryDark,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: const Icon(Icons.save_outlined),
          label: Text(_submitting ? 'Submitting...' : 'Submit Attendance'),
        ),
      ],
    );
  }
}

class _FacultyAssignmentsTab extends StatefulWidget {
  final FacultyDashboardData data;
  final String facultyId;
  final FacultyModuleService service;
  final Future<void> Function() onRefreshParent;

  const _FacultyAssignmentsTab({
    required this.data,
    required this.facultyId,
    required this.service,
    required this.onRefreshParent,
  });

  @override
  State<_FacultyAssignmentsTab> createState() => _FacultyAssignmentsTabState();
}

class _FacultyAssignmentsTabState extends State<_FacultyAssignmentsTab> {
  String? _courseId;
  _ComposerMode _mode = _ComposerMode.assignment;
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _assignmentMarksCtrl = TextEditingController(text: '100');
  final _quizDurationCtrl = TextEditingController(text: '15');
  final _quizMarksCtrl = TextEditingController(text: '10');
  final List<_QuizQuestionDraft> _quizQuestions = [_QuizQuestionDraft()];
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _assignmentMarksCtrl.dispose();
    _quizDurationCtrl.dispose();
    _quizMarksCtrl.dispose();
    for (final question in _quizQuestions) {
      question.dispose();
    }
    super.dispose();
  }

  Future<void> _createAssignment() async {
    if (_courseId == null || _titleCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await widget.service.createAssignment(
      facultyId: widget.facultyId,
      courseId: _courseId!,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      dueDate: _dueDate,
      totalMarks: int.tryParse(_assignmentMarksCtrl.text.trim()) ?? 100,
    );
    if (!mounted) return;
    _titleCtrl.clear();
    _descCtrl.clear();
    await widget.onRefreshParent();
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Assignment created and students notified.'),
      ),
    );
  }

  Future<void> _createQuiz() async {
    if (_courseId == null || _titleCtrl.text.trim().isEmpty) return;
    final questions = _quizQuestions
        .map((question) => question.toMap())
        .where((question) => (question['questionText'] as String).isNotEmpty)
        .toList();
    if (questions.isEmpty) return;

    setState(() => _saving = true);
    await widget.service.createQuiz(
      facultyId: widget.facultyId,
      courseId: _courseId!,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      durationMinutes: int.tryParse(_quizDurationCtrl.text.trim()) ?? 15,
      totalMarks:
          int.tryParse(_quizMarksCtrl.text.trim()) ??
          questions.fold<int>(
            0,
            (sum, q) => sum + ((q['marks'] as num?)?.toInt() ?? 1),
          ),
      questions: questions,
    );
    if (!mounted) return;
    _titleCtrl.clear();
    _descCtrl.clear();
    _quizDurationCtrl.text = '15';
    _quizMarksCtrl.text = '10';
    for (final question in _quizQuestions) {
      question.dispose();
    }
    _quizQuestions
      ..clear()
      ..add(_QuizQuestionDraft());
    await widget.onRefreshParent();
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Quiz created and students notified.')),
    );
  }

  Future<void> _showQuizScores(QuizModel quiz) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return FutureBuilder<List<QuizAttemptSummary>>(
            future: widget.service.fetchQuizAttempts(quiz.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              final attempts = snapshot.data ?? [];
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  Text(
                    quiz.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${attempts.length} student submissions',
                    style: const TextStyle(color: AppColors.ink500),
                  ),
                  const SizedBox(height: 14),
                  if (attempts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('No one has submitted this quiz yet.'),
                      ),
                    )
                  else
                    ...attempts.map(
                      (attempt) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                attempt.studentName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                attempt.studentEmail.isEmpty
                                    ? attempt.submission.studentId
                                    : attempt.studentEmail,
                                style: const TextStyle(color: AppColors.ink500),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Score: ${attempt.submission.score}/${attempt.totalMarks} (${attempt.percentage.toStringAsFixed(0)}%)',
                                style: const TextStyle(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Submitted: ${DateFormat('dd MMM, hh:mm a').format(attempt.submission.submittedAt.toDate())}',
                                style: const TextStyle(color: AppColors.ink500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openMaterial(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid material link.')));
      return;
    }

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the material.')),
      );
    }
  }

  Future<void> _uploadMaterial() async {
    if (widget.data.courses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a course before uploading materials.'),
        ),
      );
      return;
    }

    final fileNameCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String selectedCourseId = _courseId ?? widget.data.courses.first.courseId;
    Uint8List? fileBytes;
    String? pickedFileName;
    bool uploading = false;

    final uploaded = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> chooseFile() async {
              final picked = await FilePicker.platform.pickFiles(
                allowMultiple: false,
                withData: true,
                type: FileType.any,
              );
              if (picked == null) return;

              final file = picked.files.single;
              if (file.bytes == null) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Could not read the selected file.'),
                  ),
                );
                return;
              }

              setDialogState(() {
                fileBytes = file.bytes;
                pickedFileName = file.name;
                if (fileNameCtrl.text.trim().isEmpty) {
                  fileNameCtrl.text = file.name;
                }
              });
            }

            Future<void> submit() async {
              if (uploading ||
                  !formKey.currentState!.validate() ||
                  fileBytes == null)
                return;
              setDialogState(() => uploading = true);
              try {
                await widget.service.uploadStudyMaterial(
                  facultyId: widget.facultyId,
                  courseId: selectedCourseId,
                  fileName: fileNameCtrl.text.trim(),
                  fileBytes: fileBytes!,
                );
                if (!mounted) return;
                Navigator.of(dialogContext).pop(true);
              } catch (error) {
                setDialogState(() => uploading = false);
                ScaffoldMessenger.of(
                  dialogContext,
                ).showSnackBar(SnackBar(content: Text(error.toString())));
              }
            }

            return AlertDialog(
              title: const Text('Upload Study Material'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedCourseId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Course'),
                        items: widget.data.courses
                            .map(
                              (course) => DropdownMenuItem<String>(
                                value: course.courseId,
                                child: Text(
                                  '${course.code} | ${course.title}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: uploading
                            ? null
                            : (value) {
                                if (value == null) return;
                                setDialogState(() => selectedCourseId = value);
                              },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: fileNameCtrl,
                        enabled: !uploading,
                        decoration: const InputDecoration(
                          labelText: 'Display name',
                          hintText: 'What students will see',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter a display name.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: uploading ? null : chooseFile,
                          icon: const Icon(Icons.attach_file_outlined),
                          label: const Text('Choose file'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          pickedFileName == null
                              ? 'No file selected yet.'
                              : 'Selected: $pickedFileName',
                          style: const TextStyle(
                            color: AppColors.ink500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: uploading
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: uploading ? null : submit,
                  child: Text(uploading ? 'Uploading...' : 'Upload'),
                ),
              ],
            );
          },
        );
      },
    );

    fileNameCtrl.dispose();

    if (uploaded == true) {
      await widget.onRefreshParent();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Study material uploaded.')));
    }
  }

  void _addQuizQuestion() {
    setState(() {
      _quizQuestions.add(_QuizQuestionDraft());
    });
  }

  void _removeQuizQuestion(int index) {
    if (_quizQuestions.length <= 1) return;
    setState(() {
      _quizQuestions[index].dispose();
      _quizQuestions.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Text(
          'FACULTY PORTAL: IIIT NAGPUR',
          style: TextStyle(
            color: Color(0xFF01695B),
            letterSpacing: 1.4,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Assignment & Resource\nCurator',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 54,
            color: AppColors.primaryDark,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Manage scholarly submissions and curate study materials for the current semester.',
          style: TextStyle(color: AppColors.ink700, height: 1.35),
        ),
        const SizedBox(height: 14),
        SegmentedButton<_ComposerMode>(
          segments: const [
            ButtonSegment(
              value: _ComposerMode.assignment,
              label: Text('Assignment'),
              icon: Icon(Icons.assignment_outlined),
            ),
            ButtonSegment(
              value: _ComposerMode.quiz,
              label: Text('Quiz'),
              icon: Icon(Icons.quiz_outlined),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (value) => setState(() => _mode = value.first),
        ),
        const SizedBox(height: 12),
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _mode == _ComposerMode.assignment
                    ? 'Create Assignment'
                    : 'Create Quiz',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _courseId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Course'),
                items: widget.data.courses
                    .map(
                      (course) => DropdownMenuItem<String>(
                        value: course.courseId,
                        child: Text(
                          '${course.code} | ${course.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                selectedItemBuilder: (context) => widget.data.courses
                    .map(
                      (course) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${course.code} | ${course.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _courseId = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              if (_mode == _ComposerMode.assignment) ...[
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 56,
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100),
                              initialDate: _dueDate,
                            );
                            if (picked != null) {
                              setState(() => _dueDate = picked);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            alignment: Alignment.center,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.event_outlined),
                                const SizedBox(width: 8),
                                Text(
                                  'Due: ${DateFormat('dd MMM').format(_dueDate)}',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _assignmentMarksCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Marks'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _quizDurationCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration (minutes)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _quizMarksCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Total marks',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._quizQuestions.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _QuizQuestionCard(
                      index: entry.key,
                      draft: entry.value,
                      onRemove: () => _removeQuizQuestion(entry.key),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _addQuizQuestion,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Add Question'),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving
                      ? null
                      : _mode == _ComposerMode.assignment
                      ? _createAssignment
                      : _createQuiz,
                  icon: const Icon(Icons.add),
                  label: Text(
                    _saving
                        ? 'Saving...'
                        : _mode == _ComposerMode.assignment
                        ? 'Create Assignment'
                        : 'Create Quiz',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Active Assignments',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 38,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 10),
        _InfoPill(label: '${widget.data.assignments.length} Pending Reviews'),
        const SizedBox(height: 12),
        ...widget.data.assignments.map(
          (assignment) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AssignmentSubmissionsScreen(
                      assignment: assignment,
                      courseCode: assignment.courseId,
                      totalStudents: 10,
                    ),
                  ),
                );
              },
              child: _GlassCard(
                accent: AppColors.primaryDark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            assignment.title,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink900,
                            ),
                          ),
                        ),
                        Text(
                          DateFormat(
                            'dd MMM, yyyy',
                          ).format(assignment.dueDate.toDate()),
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Course: ${assignment.courseId}',
                      style: const TextStyle(color: AppColors.ink700),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.verified_outlined,
                          size: 16,
                          color: Color(0xFF01695B),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '85% Participation',
                          style: TextStyle(color: AppColors.ink700),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {},
                          child: const Text('Edit Requirements'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (widget.data.assignments.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'No assignments created yet.',
              style: TextStyle(color: AppColors.ink500),
            ),
          ),
        const Divider(),
        const SizedBox(height: 8),
        const Text(
          'Active Quizzes',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 38,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 12),
        if (widget.data.quizzes.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'No quizzes created yet.',
              style: TextStyle(color: AppColors.ink500),
            ),
          )
        else
          ...widget.data.quizzes.map(
            (quiz) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => _showQuizScores(quiz),
                child: _GlassCard(
                  accent: AppColors.primaryDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quiz.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Course: ${quiz.courseId}',
                        style: const TextStyle(color: AppColors.ink700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Total marks: ${quiz.totalMarks}',
                        style: const TextStyle(color: AppColors.ink700),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Tap to view student scores',
                        style: TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const Divider(),
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Study Material',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 38,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _uploadMaterial,
              icon: const Icon(Icons.upload_file_outlined, size: 16),
              label: const Text('UPLOAD FILE'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _GlassCard(
          child: Column(
            children: widget.data.materials.isEmpty
                ? [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No study materials uploaded yet.',
                        style: TextStyle(color: AppColors.ink500),
                      ),
                    ),
                  ]
                : [
                    ...widget.data.materials.map(
                      (material) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _MaterialTile(
                          fileName: material.fileName,
                          onTap: () => _openMaterial(material.fileUrl),
                          meta:
                              '${material.courseId} • ${DateFormat('dd MMM, yyyy').format(material.uploadedAt.toDate())}',
                          isLink: false,
                        ),
                      ),
                    ),
                  ],
          ),
        ),
      ],
    );
  }
}

class _QuizQuestionCard extends StatelessWidget {
  final int index;
  final _QuizQuestionDraft draft;
  final VoidCallback onRemove;

  const _QuizQuestionCard({
    required this.index,
    required this.draft,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Question ${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
              const Spacer(),
              if (index > 0)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.danger,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: draft.questionCtrl,
            decoration: const InputDecoration(labelText: 'Question text'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: draft.optionACtrl,
                  decoration: const InputDecoration(labelText: 'Option A'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: draft.optionBCtrl,
                  decoration: const InputDecoration(labelText: 'Option B'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: draft.optionCCtrl,
                  decoration: const InputDecoration(labelText: 'Option C'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: draft.optionDCtrl,
                  decoration: const InputDecoration(labelText: 'Option D'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: draft.answerCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Correct answer text',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: draft.marksCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Marks'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FacultyNotificationsTab extends StatefulWidget {
  final FacultyDashboardData data;
  final String facultyId;
  final FacultyModuleService service;
  final Future<void> Function() onRefreshParent;

  const _FacultyNotificationsTab({
    required this.data,
    required this.facultyId,
    required this.service,
    required this.onRefreshParent,
  });

  @override
  State<_FacultyNotificationsTab> createState() =>
      _FacultyNotificationsTabState();
}

class _FacultyNotificationsTabState extends State<_FacultyNotificationsTab> {
  String? _courseId;
  final _messageCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendAnnouncement() async {
    final message = _messageCtrl.text.trim();
    if (_courseId == null || message.isEmpty) return;
    setState(() => _sending = true);
    await widget.service.sendAnnouncement(
      facultyId: widget.facultyId,
      message: message,
      courseId: _courseId,
    );
    if (!mounted) return;
    _messageCtrl.clear();
    await widget.onRefreshParent();
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Announcement sent to enrolled students.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Send Announcement',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _courseId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Target course'),
          items: widget.data.courses
              .map(
                (course) => DropdownMenuItem<String>(
                  value: course.courseId,
                  child: Text(
                    '${course.code} | ${course.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          selectedItemBuilder: (context) => widget.data.courses
              .map(
                (course) => Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${course.code} | ${course.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _courseId = value),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _messageCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Announcement message',
            hintText: 'Type announcement for selected course...',
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _sending ? null : _sendAnnouncement,
          icon: const Icon(Icons.send_outlined),
          label: Text(_sending ? 'Sending...' : 'Send Announcement'),
        ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 8),
        const Text(
          'Recent Notifications',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        const SizedBox(height: 10),
        ...widget.data.announcements.map(
          (notification) => Card(
            child: ListTile(
              title: Text(notification.title),
              subtitle: Text(notification.message),
            ),
          ),
        ),
        if (widget.data.announcements.isEmpty)
          const Text('No announcements created by this faculty yet.'),
      ],
    );
  }
}

class _FacultyProfileTab extends StatelessWidget {
  final String userName;
  final String email;
  final String department;
  final String designation;
  final String employeeId;
  final List<CourseModel> courses;
  final VoidCallback onLogout;

  const _FacultyProfileTab({
    required this.userName,
    required this.email,
    required this.department,
    required this.designation,
    required this.employeeId,
    required this.courses,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 58,
              backgroundColor: AppColors.primaryDark,
              child: Text(
                _initials(userName),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _InfoPill(label: 'FACULTY PROFILE'),
                  const SizedBox(height: 8),
                  Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 46,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$designation, Dept. of $department',
                    style: const TextStyle(color: AppColors.ink700),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _TinyInfo(icon: Icons.badge_outlined, text: 'ID: $employeeId'),
            _TinyInfo(icon: Icons.email_outlined, text: email),
          ],
        ),
        const SizedBox(height: 16),
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Research Interests',
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 38,
                ),
              ),
              SizedBox(height: 10),
              _InterestTile(
                title: 'Cognitive Aesthetics',
                subtitle:
                    'Exploring the intersection of human perception and digital forms.',
                icon: Icons.psychology_alt_outlined,
              ),
              SizedBox(height: 10),
              _InterestTile(
                title: 'Renaissance Revival',
                subtitle:
                    'Applying classical composition techniques to modern interface design.',
                icon: Icons.draw_outlined,
              ),
              SizedBox(height: 10),
              _InterestTile(
                title: 'Networked Pedagogy',
                subtitle:
                    'Decentralized models for collective learning in arts education.',
                icon: Icons.hub_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _GlassCard(
          child: Column(
            children: [
              _FieldRow(label: 'Designation', value: designation),
              _FieldRow(label: 'Department', value: department),
              _FieldRow(label: 'Employee ID', value: employeeId),
              const _FieldRow(label: 'Working Status', value: 'Active'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Teaching History',
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Semester 5 demo courses attached to this faculty profile.',
                style: const TextStyle(color: AppColors.ink700, height: 1.4),
              ),
              const SizedBox(height: 12),
              if (courses
                  .where((course) => course.semesterNumber == 5)
                  .isNotEmpty)
                ...courses
                    .where((course) => course.semesterNumber == 5)
                    .map(
                      (course) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceWarm,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryDark,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  course.code.isNotEmpty
                                      ? course.code.substring(
                                          0,
                                          course.code.length >= 2
                                              ? 2
                                              : course.code.length,
                                        )
                                      : '--',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      course.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.ink900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${course.code} • ${course.semester} • ${course.department.isEmpty ? 'CSE' : course.department}',
                                      style: const TextStyle(
                                        color: AppColors.ink500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
              if (courses.where((course) => course.semesterNumber == 5).isEmpty)
                const Text(
                  'No Semester 5 courses are linked to this profile right now.',
                  style: TextStyle(color: AppColors.ink500),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _GlassCard(
          accent: const Color(0xFF9AD2CB),
          child: const Text(
            'Insight Module\nTop Researcher 2023',
            style: TextStyle(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout_outlined, color: AppColors.danger),
          label: const Text(
            'Logout from Portal',
            style: TextStyle(color: AppColors.danger),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.danger),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final Color? accent;

  const _GlassCard({required this.child, this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent ?? AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MetricBlock extends StatelessWidget {
  final String value;
  final String label;

  const _MetricBlock({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 58,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: AppColors.ink700, height: 1.2),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;

  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.ink100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(color: AppColors.ink700, fontSize: 12),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _ActionTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: _GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.ink900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.ink500,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final String timeLabel;
  final String meridiem;
  final String title;
  final String subtitle;
  final Color accent;

  const _ScheduleCard({
    required this.timeLabel,
    required this.meridiem,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      child: ListTile(
        leading: SizedBox(
          width: 50,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                timeLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
              Text(
                meridiem,
                style: const TextStyle(fontSize: 11, color: AppColors.ink500),
              ),
            ],
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.more_vert),
      ),
    );
  }
}

class _GlassStatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color accent;

  const _GlassStatCard({
    required this.title,
    required this.value,
    this.accent = const Color(0xFF01695B),
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.ink500,
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 46,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseTile extends StatelessWidget {
  final String title;
  final String code;
  final String semester;
  final int students;
  final Color accent;
  final VoidCallback onUploadResults;

  const _CourseTile({
    required this.title,
    required this.code,
    required this.semester,
    required this.students,
    required this.accent,
    required this.onUploadResults,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.widgets_outlined, color: accent, size: 18),
              ),
              const Spacer(),
              _InfoPill(label: students > 100 ? 'ACTIVE' : 'ELECTIVE'),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 40,
              height: 1.05,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$code • $semester',
            style: const TextStyle(color: AppColors.ink500),
          ),
          const SizedBox(height: 10),
          const Divider(),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$students Students',
                  style: const TextStyle(color: AppColors.ink700),
                ),
              ),
              TextButton.icon(
                onPressed: onUploadResults,
                icon: const Icon(Icons.upload_outlined, size: 16),
                label: const Text('Upload Results'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accent;

  const _SummaryStrip({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      accent: accent,
      child: Column(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: accent.withOpacity(0.12),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(color: AppColors.ink500, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 36,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;

  const _InfoPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF9DE7DA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF01695B),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MaterialTile extends StatelessWidget {
  final String fileName;
  final String meta;
  final bool isLink;
  final VoidCallback? onTap;

  const _MaterialTile({
    required this.fileName,
    required this.meta,
    this.isLink = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceWarm,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isLink
                    ? const Color(0xFFD9F1ED)
                    : const Color(0xFFF8E5E7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isLink ? Icons.link_outlined : Icons.picture_as_pdf_outlined,
                color: isLink ? const Color(0xFF01695B) : AppColors.danger,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    style: const TextStyle(
                      color: AppColors.ink500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TinyInfo extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TinyInfo({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryDark),
          const SizedBox(width: 6),
          Text(text),
        ],
      ),
    );
  }
}

class _InterestTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _InterestTile({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF01695B)),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 22,
              color: AppColors.ink900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.ink500, height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final String label;
  final String value;

  const _FieldRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: AppColors.ink500)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'F';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}
