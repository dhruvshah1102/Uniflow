import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/admin_module_service.dart';

class UserManagementTab extends StatefulWidget {
  final AdminModuleService service;
  final Future<void> Function() onChanged;
  final String adminUid;

  const UserManagementTab({
    super.key,
    required this.service,
    required this.onChanged,
    required this.adminUid,
  });

  @override
  State<UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<UserManagementTab> {
  bool _normalizing = false;

  Future<void> _normalizeUsers() async {
    if (_normalizing) return;
    setState(() => _normalizing = true);
    try {
      final report = await widget.service.normalizeUserRecords();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Normalized ${report.updated} users. ${report.flagged} records needed role cleanup.',
          ),
        ),
      );
      await widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _normalizing = false);
    }
  }

  Future<void> _resetCanonicalData() async {
    if (_normalizing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset canonical data?'),
        content: const Text(
          'This will replace Firestore users, courses, enrollments, attendance, assignments, notifications, and registrations with the canonical campus dataset. Firebase Auth accounts will stay untouched.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _normalizing = true);
    try {
      await widget.service.resetCanonicalDataset(adminUid: widget.adminUid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Canonical Firestore data uploaded successfully.')),
      );
      await widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _normalizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminUserItem>>(
      stream: widget.service.streamAllUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(snapshot.error.toString(), textAlign: TextAlign.center),
            ),
          );
        }

        final users = snapshot.data ?? [];
        final students = users.where((u) => u.role == 'student').toList();
        final faculty = users.where((u) => u.role == 'faculty').toList();
        final admins = users.where((u) => u.role == 'admin').toList();
        final studentGroups = _groupStudents(students);
        final facultyGroups = _groupFaculty(faculty);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const Text(
              'INSTITUTIONAL RECORDS',
              style: TextStyle(color: Color(0xFF01695B), letterSpacing: 1.2, fontWeight: FontWeight.w700, fontSize: 11),
            ),
            const SizedBox(height: 8),
            const Text(
              'User Management',
              style: TextStyle(color: AppColors.primaryDark, fontSize: 40, fontWeight: FontWeight.w800, height: 1.05),
            ),
            const SizedBox(height: 10),
            const Text(
              'Users are grouped the same way an academic ERP is usually organized, so large lists stay usable.',
              style: TextStyle(color: AppColors.ink700, height: 1.35),
            ),
            const SizedBox(height: 16),
            _SummaryBar(
              students: students.length,
              faculty: faculty.length,
              admins: admins.length,
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Refresh',
                onPressed: widget.onChanged,
                icon: const Icon(Icons.refresh),
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Students',
              subtitle: 'Semester -> Division -> Students',
              child: studentGroups.isEmpty
                  ? const _EmptyState(message: 'No student records found.')
                  : Column(
                      children: studentGroups.entries
                          .map(
                            (semesterEntry) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                                collapsedBackgroundColor: AppColors.surfaceWarm,
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: Text(
                                  'Semester ${semesterEntry.key}',
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                subtitle: Text('${semesterEntry.value.values.fold<int>(0, (sum, list) => sum + list.length)} students'),
                                children: semesterEntry.value.entries
                                    .map(
                                      (divisionEntry) => Padding(
                                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                        child: ExpansionTile(
                                          tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                                          collapsedBackgroundColor: Colors.white,
                                          backgroundColor: const Color(0xFFF8FAFC),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                          title: Text(
                                            'Division ${divisionEntry.key}',
                                            style: const TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                          subtitle: Text('${divisionEntry.value.length} students'),
                                          children: divisionEntry.value
                                              .map((student) => _UserRow(item: student))
                                              .toList(),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Faculty',
              subtitle: 'Department -> Faculty List',
              child: facultyGroups.isEmpty
                  ? const _EmptyState(message: 'No faculty records found.')
                  : Column(
                      children: facultyGroups.entries
                          .map(
                            (departmentEntry) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                                collapsedBackgroundColor: AppColors.surfaceWarm,
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: Text(
                                  departmentEntry.key,
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                subtitle: Text('${departmentEntry.value.length} faculty members'),
                                children: departmentEntry.value.map((item) => _UserRow(item: item)).toList(),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Administrators',
              subtitle: 'Active admin accounts',
              child: admins.isEmpty
                  ? const _EmptyState(message: 'No admin records found.')
                  : Column(
                      children: admins.map((item) => _UserRow(item: item)).toList(),
                    ),
            ),
          ],
        );
      },
    );
  }

  Map<int, Map<String, List<AdminUserItem>>> _groupStudents(List<AdminUserItem> students) {
    final grouped = <int, Map<String, List<AdminUserItem>>>{};
    for (final student in students) {
      final semester = student.semester ?? 1;
      final division = student.division.trim().isEmpty ? 'A' : student.division.trim().toUpperCase();
      grouped.putIfAbsent(semester, () => {});
      grouped[semester]!.putIfAbsent(division, () => []);
      grouped[semester]![division]!.add(student);
    }

    final ordered = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return {
      for (final semesterEntry in ordered)
        semesterEntry.key: {
          for (final divisionEntry in (semesterEntry.value.entries.toList()..sort((a, b) => a.key.compareTo(b.key))))
            divisionEntry.key: (divisionEntry.value..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()))),
        },
    };
  }

  Map<String, List<AdminUserItem>> _groupFaculty(List<AdminUserItem> faculty) {
    final grouped = <String, List<AdminUserItem>>{};
    for (final item in faculty) {
      final department = item.department.trim().isEmpty ? 'Unknown' : item.department.trim();
      grouped.putIfAbsent(department, () => []);
      grouped[department]!.add(item);
    }
    final ordered = grouped.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    return {
      for (final entry in ordered)
        entry.key: (entry.value..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()))),
    };
  }
}

class _SummaryBar extends StatelessWidget {
  final int students;
  final int faculty;
  final int admins;

  const _SummaryBar({
    required this.students,
    required this.faculty,
    required this.admins,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatCard(title: 'Students', value: '$students')),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(title: 'Faculty', value: '$faculty')),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(title: 'Admins', value: '$admins')),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink900)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: AppColors.ink500)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final AdminUserItem item;

  const _UserRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = switch (item.role) {
      'faculty' => AppColors.primaryDark,
      'admin' => AppColors.danger,
      _ => const Color(0xFF01695B),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withOpacity(0.12),
            child: Text(
              item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(item.email, style: const TextStyle(color: AppColors.ink500)),
                const SizedBox(height: 4),
                Text(
                  item.role == 'student'
                      ? 'Dept: ${item.department} | Sem ${item.semester ?? '-'} | Div ${item.division}'
                      : item.role == 'faculty'
                          ? 'Dept: ${item.department}'
                          : 'Admin account',
                  style: const TextStyle(color: AppColors.ink700),
                ),
              ],
            ),
          ),
          Text(
            item.role.toUpperCase(),
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;

  const _StatCard({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: AppColors.ink500, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(message, style: const TextStyle(color: AppColors.ink500)),
    );
  }
}
