import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/admin_module_service.dart';
import 'user_management_tab.dart';

enum _AdminTab { dashboard, users, courses, registrations, reports, profile }

class AdminModuleScreen extends StatefulWidget {
  const AdminModuleScreen({super.key});

  @override
  State<AdminModuleScreen> createState() => _AdminModuleScreenState();
}

class _AdminModuleScreenState extends State<AdminModuleScreen> {
  final AdminModuleService _service = AdminModuleService.instance;
  _AdminTab _tab = _AdminTab.dashboard;
  Future<AdminOverview>? _overviewFuture;
  Future<List<CourseReportItem>>? _reportsFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _overviewFuture ??= _service.fetchOverview();
    _reportsFuture ??= _service.fetchCourseReports();
  }

  Future<void> _reload() async {
    setState(() {
      _overviewFuture = _service.fetchOverview();
      _reportsFuture = _service.fetchCourseReports();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (user.role != 'admin') {
      return Scaffold(
        appBar: AppBar(title: const Text('Access denied')),
        body: const Center(child: Text('Only admin accounts can access this module.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceWarm,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceWarm,
        title: const Text('Uniflow Admin', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: auth.logout, icon: const Icon(Icons.logout_outlined)),
        ],
      ),
      body: IndexedStack(
        index: _tab.index,
        children: [
          _DashboardTab(overviewFuture: _overviewFuture),
          UserManagementTab(service: _service, onChanged: _reload),
          _CoursesTab(service: _service, onChanged: _reload),
          _RegistrationsTab(service: _service, adminId: user.id, onChanged: _reload),
          _ReportsTab(reportsFuture: _reportsFuture),
          _ProfileTab(name: user.name, email: user.email, onLogout: auth.logout),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _tab.index,
        onTap: (index) => setState(() => _tab = _AdminTab.values[index]),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: 'Users'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book_outlined), label: 'Courses'),
          BottomNavigationBarItem(icon: Icon(Icons.fact_check_outlined), label: 'Registrations'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  final Future<AdminOverview>? overviewFuture;
  const _DashboardTab({required this.overviewFuture});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminOverview>(
      future: overviewFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text(snapshot.error.toString(), textAlign: TextAlign.center));
        final d = snapshot.data ?? const AdminOverview(totalStudents: 0, totalFaculty: 0, totalCourses: 0, pendingRegistrations: 0);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Uniflow', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
            const SizedBox(height: 4),
            const Text('Unified Digital Campus Platform - IIIT Nagpur', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink500)),
            const SizedBox(height: 12),
            _StatTile(label: 'Total Students', value: '${d.totalStudents}'),
            _StatTile(label: 'Total Faculty', value: '${d.totalFaculty}'),
            _StatTile(label: 'Total Courses', value: '${d.totalCourses}'),
            _StatTile(label: 'Pending Registrations', value: '${d.pendingRegistrations}'),
          ],
        );
      },
    );
  }
}

class _UsersTab extends StatelessWidget {
  final AdminModuleService service;
  final String roleFilter;
  final ValueChanged<String> onFilterChange;
  final Future<void> Function() onChanged;
  const _UsersTab({required this.service, required this.roleFilter, required this.onFilterChange, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(child: DropdownButtonFormField<String>(value: roleFilter, items: const [DropdownMenuItem(value: 'all', child: Text('All')), DropdownMenuItem(value: 'student', child: Text('Students')), DropdownMenuItem(value: 'faculty', child: Text('Faculty')), DropdownMenuItem(value: 'admin', child: Text('Admins'))], onChanged: (v) => v == null ? null : onFilterChange(v))),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () async {
              await service.addOrUpdateUser(name: 'New Student', email: 'student.${DateTime.now().millisecondsSinceEpoch}@iiitn.ac.in', role: 'student', department: 'CSE', semester: 5);
              await onChanged();
            },
              child: const Text('Add User'),
          ),
        ]),
      ),
      Expanded(
        child: StreamBuilder<List<AdminUserItem>>(
          stream: service.streamUsers(roleFilter: roleFilter),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return Center(child: Text(snapshot.error.toString(), textAlign: TextAlign.center));
            final users = snapshot.data ?? [];
            return ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, i) {
                final u = users[i];
                return ListTile(title: Text(u.name), subtitle: Text('${u.email} • ${u.role} • ${u.department}'), trailing: u.semester == null ? null : Text('Sem ${u.semester}'));
              },
            );
          },
        ),
      ),
    ]);
  }
}

class _CoursesTab extends StatelessWidget {
  final AdminModuleService service;
  final Future<void> Function() onChanged;
  const _CoursesTab({required this.service, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: () async {
            final faculty = await service.fetchFacultyUsers();
            if (faculty.isEmpty) return;
            final id = DateTime.now().millisecondsSinceEpoch.toString();
            await service.createCourse(
              courseName: 'New Course $id',
              courseCode: 'NC$id',
              credits: 3,
              semester: 5,
              department: 'CSE',
              facultyId: faculty.first.uidFirebase,
              facultyName: faculty.first.name,
            );
            await onChanged();
          },
          child: const Text('Create Course'),
        ),
      ),
      Expanded(
        child: StreamBuilder<List<AdminCourseItem>>(
          stream: service.streamCourses(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return Center(child: Text(snapshot.error.toString(), textAlign: TextAlign.center));
            final courses = snapshot.data ?? [];
            return ListView.builder(
              itemCount: courses.length,
              itemBuilder: (context, i) {
                final c = courses[i];
                return ListTile(title: Text('${c.code} - ${c.courseName}'), subtitle: Text('Faculty: ${c.facultyName}'));
              },
            );
          },
        ),
      ),
    ]);
  }
}

class _RegistrationsTab extends StatelessWidget {
  final AdminModuleService service;
  final String adminId;
  final Future<void> Function() onChanged;
  const _RegistrationsTab({required this.service, required this.adminId, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminRegistrationItem>>(
      stream: service.streamPendingRegistrations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text(snapshot.error.toString(), textAlign: TextAlign.center));
        final items = snapshot.data ?? [];
        if (items.isEmpty) return const Center(child: Text('No pending registrations.'));
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, i) {
            final r = items[i];
            return ListTile(
              title: Text('Student: ${r.studentId}'),
              subtitle: Text('Course: ${r.courseId}'),
              trailing: Wrap(
                spacing: 8,
                children: [
                  IconButton(onPressed: () async { await service.rejectRegistration(registrationId: r.id, adminId: adminId); await onChanged(); }, icon: const Icon(Icons.close, color: AppColors.danger)),
                  IconButton(onPressed: () async { await service.approveRegistration(registrationId: r.id, adminId: adminId); await onChanged(); }, icon: const Icon(Icons.check, color: AppColors.success)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ReportsTab extends StatelessWidget {
  final Future<List<CourseReportItem>>? reportsFuture;
  const _ReportsTab({required this.reportsFuture});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CourseReportItem>>(
      future: reportsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text(snapshot.error.toString(), textAlign: TextAlign.center));
        final reports = snapshot.data ?? [];
        return ListView.builder(
          itemCount: reports.length,
          itemBuilder: (context, i) {
            final r = reports[i];
            return ListTile(
              title: Text('${r.course.code} - ${r.course.courseName}'),
              subtitle: Text('Students: ${r.totalStudents} • Attendance: ${r.attendancePercent.toStringAsFixed(1)}%'),
            );
          },
        );
      },
    );
  }
}

class _ProfileTab extends StatelessWidget {
  final String name;
  final String email;
  final VoidCallback onLogout;
  const _ProfileTab({required this.name, required this.email, required this.onLogout});
  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Text(email),
      const SizedBox(height: 20),
      FilledButton.icon(onPressed: onLogout, icon: const Icon(Icons.logout), label: const Text('Logout')),
    ]);
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  const _StatTile({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
      ),
    );
  }
}
