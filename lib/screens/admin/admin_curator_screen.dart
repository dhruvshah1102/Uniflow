import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/admin_module_service.dart';
import 'create_course_tab.dart';
import 'user_management_tab.dart';
import 'semester_registration_review_tab.dart';

enum _Tab { dashboard, users, courses, registrations, reports, profile }

class AdminCuratorScreen extends StatefulWidget {
  const AdminCuratorScreen({super.key});

  @override
  State<AdminCuratorScreen> createState() => _AdminCuratorScreenState();
}

class _AdminCuratorScreenState extends State<AdminCuratorScreen> {
  final AdminModuleService _service = AdminModuleService.instance;
  _Tab _tab = _Tab.dashboard;
  Stream<AdminOverview>? _overviewStream;
  Stream<List<CourseReportItem>>? _reportsStream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _overviewStream ??= _service.watchOverview();
    _reportsStream ??= _service.watchCourseReports();
  }

  Future<void> _refreshAll() async {
    setState(() {
      _overviewStream = _service.watchOverview();
      _reportsStream = _service.watchCourseReports();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    if (user == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (user.role != 'admin') {
      return Scaffold(
        appBar: AppBar(title: const Text('Access denied')),
        body: const Center(
          child: Text('Only admin accounts can access this module.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F6FA),
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: const Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryDark,
              child: Icon(Icons.person, color: Colors.white, size: 16),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Academic Curator',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(onPressed: _refreshAll, icon: const Icon(Icons.refresh)),
          IconButton(
            onPressed: auth.logout,
            icon: const Icon(Icons.logout_outlined),
          ),
        ],
      ),
      body: _buildSelectedTab(user, auth.logout),
      bottomNavigationBar: _BottomBar(
        currentIndex: _tab.index,
        onTap: (index) => setState(() => _tab = _Tab.values[index]),
      ),
    );
  }

  Widget _buildSelectedTab(dynamic user, VoidCallback onLogout) {
    switch (_tab) {
      case _Tab.dashboard:
        return _DashboardTab(
          overviewStream: _overviewStream,
          onRefresh: _refreshAll,
        );
      case _Tab.users:
        return UserManagementTab(
          service: _service,
          adminUid: user.id,
          onChanged: _refreshAll,
        );
      case _Tab.courses:
        return CreateCourseTab(service: _service, onChanged: _refreshAll);
      case _Tab.registrations:
        return SemesterRegistrationReviewTab(
          adminId: user.id,
          onChanged: _refreshAll,
        );
      case _Tab.reports:
        return _ReportsTab(
          reportsStream: _reportsStream,
          onRefresh: _refreshAll,
        );
      case _Tab.profile:
        return _ProfileTab(
          name: user.name,
          email: user.email,
          onLogout: onLogout,
        );
    }
  }
}

class _DashboardTab extends StatelessWidget {
  final Stream<AdminOverview>? overviewStream;
  final Future<void> Function() onRefresh;
  const _DashboardTab({required this.overviewStream, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AdminOverview>(
      stream: overviewStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return _ErrorState(
            text: snapshot.error.toString(),
            onRetry: onRefresh,
          );
        final data =
            snapshot.data ??
            const AdminOverview(
              totalStudents: 0,
              totalFaculty: 0,
              totalCourses: 0,
              pendingRegistrations: 0,
            );
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          children: [
            const Text(
              'SYSTEM OVERVIEW',
              style: TextStyle(
                color: Color(0xFF01695B),
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hello, Admin',
              style: TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w800,
                fontSize: 42,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Welcome back to the IIIT Nagpur Academic Portal.',
              style: TextStyle(color: AppColors.ink700),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.auto_graph),
                label: const Text('Generate Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _MetricCard(
              title: 'TOTAL STUDENTS',
              value: '${data.totalStudents}',
              leading: Icons.groups_2_outlined,
              accent: AppColors.primaryDark,
            ),
            const SizedBox(height: 10),
            _MetricCard(
              title: 'TOTAL FACULTY',
              value: '${data.totalFaculty}',
              leading: Icons.school_outlined,
              accent: const Color(0xFF01695B),
            ),
            const SizedBox(height: 10),
            _MetricCard(
              title: 'TOTAL COURSES',
              value: '${data.totalCourses}',
              leading: Icons.book_outlined,
              accent: AppColors.primaryDark,
            ),
            const SizedBox(height: 10),
            _MetricCard(
              title: 'PENDING REGISTRATIONS',
              value: '${data.pendingRegistrations}',
              leading: Icons.assignment_late_outlined,
              accent: AppColors.danger,
            ),
          ],
        );
      },
    );
  }
}

class _UsersTab extends StatelessWidget {
  final AdminModuleService service;
  final String roleFilter;
  final ValueChanged<String> onFilterChanged;
  final Future<void> Function() onChanged;
  const _UsersTab({
    required this.service,
    required this.roleFilter,
    required this.onFilterChanged,
    required this.onChanged,
  });

  Future<void> _addQuickUser(BuildContext context) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final email = 'student.$ts@iiitn.ac.in';
    const password = 'Uniflow@1234';
    await service.createFirebaseAuthUser(
      name: 'Student $ts',
      email: email,
      password: password,
      role: 'student',
      department: 'CSE',
      semester: 1,
      division: 'A',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Created $email with temporary password $password'),
      ),
    );
    await onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'INSTITUTIONAL RECORDS',
                style: TextStyle(
                  color: Color(0xFF01695B),
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'User Management',
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _addQuickUser(context),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Add User'),
                ),
              ),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('All')),
                  ButtonSegment(value: 'student', label: Text('Student')),
                  ButtonSegment(value: 'faculty', label: Text('Faculty')),
                  ButtonSegment(value: 'admin', label: Text('Admin')),
                ],
                selected: {roleFilter},
                onSelectionChanged: (value) => onFilterChanged(value.first),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<AdminUserItem>>(
            stream: service.streamUsers(roleFilter: roleFilter),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError)
                return _ErrorState(
                  text: snapshot.error.toString(),
                  onRetry: onChanged,
                );
              final users = snapshot.data ?? [];
              if (users.isEmpty)
                return const Center(child: Text('No users found.'));
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: users.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final user = users[index];
                  final roleColor = user.role == 'faculty'
                      ? AppColors.primaryDark
                      : (user.role == 'admin'
                            ? AppColors.danger
                            : const Color(0xFF01695B));
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: roleColor.withOpacity(0.14),
                                child: Text(
                                  user.name.isNotEmpty
                                      ? user.name[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: roleColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  user.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 22,
                                  ),
                                ),
                              ),
                              Text(
                                user.role.toUpperCase(),
                                style: TextStyle(
                                  color: roleColor,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Text(
                            'Department: ${user.department}',
                            style: const TextStyle(color: AppColors.ink700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID: ${user.id}',
                            style: const TextStyle(color: AppColors.ink700),
                          ),
                          if (user.semester != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Semester: ${user.semester}',
                              style: const TextStyle(color: AppColors.ink700),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CoursesTab extends StatelessWidget {
  final AdminModuleService service;
  final Future<void> Function() onChanged;
  const _CoursesTab({required this.service, required this.onChanged});

  Future<void> _addQuickCourse() async {
    final faculty = await service.fetchFacultyUsers();
    if (faculty.isEmpty) return;
    final id = DateTime.now().millisecondsSinceEpoch;
    await service.createOrUpdateCourse(
      courseId: 'course$id',
      courseName: 'New Department Course',
      code: 'NC$id',
      credits: 3,
      semester: 'Semester 5',
      department: 'CSE',
      facultyId: faculty.first.id,
      facultyName: faculty.first.name,
    );
    await onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Course Management',
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 44,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _addQuickCourse,
                icon: const Icon(Icons.add),
                label: const Text('Create Course'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<AdminCourseItem>>(
            stream: service.streamCourses(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError)
                return _ErrorState(
                  text: snapshot.error.toString(),
                  onRetry: onChanged,
                );
              final courses = snapshot.data ?? [];
              if (courses.isEmpty)
                return const Center(child: Text('No courses found.'));
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: courses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final c = courses[index];
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0x1A01695B),
                        child: Icon(Icons.menu_book, color: Color(0xFF01695B)),
                      ),
                      title: Text(
                        c.courseName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${c.code} • ${c.semester}\nAssigned: ${c.facultyName.isEmpty ? 'Unassigned' : c.facultyName}',
                      ),
                      isThreeLine: true,
                      trailing: Text(
                        '${c.credits}cr',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RegistrationsTab extends StatelessWidget {
  final AdminModuleService service;
  final String adminId;
  final Future<void> Function() onChanged;
  const _RegistrationsTab({
    required this.service,
    required this.adminId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminRegistrationItem>>(
      stream: service.streamPendingRegistrations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return _ErrorState(
            text: snapshot.error.toString(),
            onRetry: onChanged,
          );
        final items = snapshot.data ?? [];
        if (items.isEmpty)
          return const Center(child: Text('No pending registrations.'));
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final r = items[i];
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.studentId,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      r.courseId,
                      style: const TextStyle(color: AppColors.ink700),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                await service.rejectRegistration(
                                  registrationId: r.id,
                                  adminId: adminId,
                                );
                                await onChanged();
                              } catch (e, stack) {
                                debugPrint(
                                  'rejectRegistration failed for ${r.id}: $e',
                                );
                                debugPrint(stack.toString());
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      e.toString().replaceFirst(
                                        'Exception: ',
                                        '',
                                      ),
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.close),
                            label: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                await service.approveRegistration(
                                  registrationId: r.id,
                                  adminId: adminId,
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Registration approved successfully.',
                                    ),
                                  ),
                                );
                                await onChanged();
                              } catch (e, stack) {
                                debugPrint(
                                  'approveRegistration failed for ${r.id}: $e',
                                );
                                debugPrint(stack.toString());
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      e.toString().replaceFirst(
                                        'Exception: ',
                                        '',
                                      ),
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.check),
                            label: const Text('Approve'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ReportsTab extends StatelessWidget {
  final Stream<List<CourseReportItem>>? reportsStream;
  final Future<void> Function() onRefresh;
  const _ReportsTab({required this.reportsStream, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CourseReportItem>>(
      stream: reportsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return _ErrorState(
            text: snapshot.error.toString(),
            onRetry: onRefresh,
          );
        final reports = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            const Text(
              'Reports & Analytics',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 44,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 12),
            ...reports.map(
              (report) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.analytics_outlined,
                      color: AppColors.primaryDark,
                    ),
                    title: Text(
                      '${report.course.code} - ${report.course.courseName}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'Students: ${report.totalStudents}\nAttendance: ${report.attendancePercent.toStringAsFixed(1)}%',
                    ),
                    isThreeLine: true,
                  ),
                ),
              ),
            ),
            if (reports.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No report data available.'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ProfileTab extends StatelessWidget {
  final String name;
  final String email;
  final VoidCallback onLogout;
  const _ProfileTab({
    required this.name,
    required this.email,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Container(
          height: 330,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFF101D3B), Color(0xFF2E4B8A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.admin_panel_settings,
              size: 120,
              color: Colors.white70,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'IIIT NAGPUR INSTITUTION PORTAL',
          style: TextStyle(
            color: Color(0xFF01695B),
            letterSpacing: 1.3,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w800,
            fontSize: 54,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 10),
        Text(email, style: const TextStyle(color: AppColors.ink700)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout),
          label: const Text('Logout from Portal'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData leading;
  final Color accent;
  const _MetricCard({
    required this.title,
    required this.value,
    required this.leading,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: accent.withOpacity(0.15),
            child: Icon(leading, color: accent),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.ink500,
                  fontSize: 11,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 34,
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String text;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.text, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 44),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      onTap: onTap,
      selectedItemColor: AppColors.primaryDark,
      unselectedItemColor: AppColors.ink300,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'DASHBOARD',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.people), label: 'USERS'),
        BottomNavigationBarItem(icon: Icon(Icons.book), label: 'COURSES'),
        BottomNavigationBarItem(icon: Icon(Icons.fact_check), label: 'REG'),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'REPORTS'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'PROFILE'),
      ],
    );
  }
}
