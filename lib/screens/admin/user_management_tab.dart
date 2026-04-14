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

  Future<void> _showCreateUserSheet() async {
    if (_normalizing) return;

    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final departmentCtrl = TextEditingController(text: 'CSE');
    final semesterCtrl = TextEditingController(text: '1');
    final divisionCtrl = TextEditingController(text: 'A');
    String role = 'student';
    var saving = false;
    var completed = false;
    String? feedbackMessage;
    bool feedbackIsError = false;

    try {
      final created = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              Future<void> submit() async {
                if (saving || !(formKey.currentState?.validate() ?? false)) return;
                setSheetState(() {
                  saving = true;
                  feedbackMessage = null;
                  feedbackIsError = false;
                });
                var succeeded = false;
                try {
                  await widget.service.createFirebaseAuthUser(
                    name: nameCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    password: passwordCtrl.text,
                    role: role,
                    department: departmentCtrl.text.trim(),
                    semester: role == 'student' ? int.tryParse(semesterCtrl.text.trim()) ?? 1 : null,
                    division: role == 'student' ? divisionCtrl.text.trim() : null,
                  );
                  succeeded = true;
                  if (!sheetContext.mounted) return;
                  setSheetState(() {
                    saving = false;
                    completed = true;
                    feedbackMessage = 'User created successfully. You can now close this panel.';
                    feedbackIsError = false;
                  });
                  try {
                    await widget.onChanged();
                  } catch (_) {
                    // The user was created already; refresh failures should not hide that result.
                  }
                } catch (e) {
                  final message = e.toString().replaceFirst('Exception: ', '');
                  if (!sheetContext.mounted) return;
                  setSheetState(() {
                    saving = false;
                    completed = false;
                    feedbackMessage = message;
                    feedbackIsError = true;
                  });
                } finally {
                  if (!succeeded && sheetContext.mounted) {
                    setSheetState(() => saving = false);
                  }
                }
              }

              return Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
                ),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Create User',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (feedbackMessage != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: feedbackIsError ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: feedbackIsError ? const Color(0xFFE57373) : const Color(0xFF81C784),
                              ),
                            ),
                            child: Text(
                              feedbackMessage!,
                              style: TextStyle(
                                color: feedbackIsError ? const Color(0xFFC62828) : const Color(0xFF1B5E20),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'Name'),
                          validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter a name.' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'Email'),
                          validator: (value) {
                            final text = (value ?? '').trim();
                            if (text.isEmpty) return 'Enter an email.';
                            if (!text.contains('@')) return 'Enter a valid email.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: passwordCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Password'),
                          validator: (value) {
                            if ((value ?? '').length < 6) return 'Password must be at least 6 characters.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: role,
                          decoration: const InputDecoration(labelText: 'Role'),
                          items: const [
                            DropdownMenuItem(value: 'student', child: Text('Student')),
                            DropdownMenuItem(value: 'faculty', child: Text('Faculty')),
                          ],
                          onChanged: saving ? null : (value) => setSheetState(() => role = value ?? 'student'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: departmentCtrl,
                          decoration: const InputDecoration(labelText: 'Department'),
                          validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter a department.' : null,
                        ),
                        if (role == 'student') ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                              child: TextFormField(
                                  controller: semesterCtrl,
                                  keyboardType: TextInputType.number,
                                  readOnly: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Starting Semester',
                                    helperText: 'Fixed at 1 for all newly created students.',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: divisionCtrl,
                                  decoration: const InputDecoration(labelText: 'Division'),
                                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter division.' : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: saving
                                ? null
                                : completed
                                    ? () => Navigator.of(sheetContext).pop(true)
                                    : submit,
                            child: Text(
                              saving
                                  ? 'Creating...'
                                  : completed
                                      ? 'Close'
                                      : 'Create User',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

      if (created == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User created successfully.')),
        );
      }
    } finally {
      nameCtrl.dispose();
      emailCtrl.dispose();
      passwordCtrl.dispose();
      departmentCtrl.dispose();
      semesterCtrl.dispose();
      divisionCtrl.dispose();
    }
  }

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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: _showCreateUserSheet,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Create User'),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: widget.onChanged,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
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
                                              .map(
                                                (student) => _UserRow(
                                                  item: student,
                                                  service: widget.service,
                                                  onDeleted: widget.onChanged,
                                                  adminUid: widget.adminUid,
                                                ),
                                              )
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
                                children: departmentEntry.value
                                    .map(
                                      (item) => _UserRow(
                                        item: item,
                                        service: widget.service,
                                        onDeleted: widget.onChanged,
                                        adminUid: widget.adminUid,
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
              title: 'Administrators',
              subtitle: 'Active admin accounts',
              child: admins.isEmpty
                  ? const _EmptyState(message: 'No admin records found.')
                  : Column(
                      children: admins
                          .map(
                            (item) => _UserRow(
                              item: item,
                              service: widget.service,
                              onDeleted: widget.onChanged,
                              adminUid: widget.adminUid,
                            ),
                          )
                          .toList(),
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
  final AdminModuleService service;
  final Future<void> Function() onDeleted;
  final String adminUid;

  const _UserRow({
    required this.item,
    required this.service,
    required this.onDeleted,
    required this.adminUid,
  });

  Future<void> _deleteUser(BuildContext context) async {
    if (item.id == adminUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot delete the currently signed-in admin account.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete user?'),
        content: Text(
          'This removes ${item.name} from Firestore and clears linked academic records. Firebase Auth deletion must be done separately from the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await service.deleteUserData(userId: item.id, role: item.role);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.name} deleted from Firestore.')),
      );
      await onDeleted();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

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
          IconButton(
            tooltip: 'Delete user',
            onPressed: () => _deleteUser(context),
            icon: const Icon(Icons.delete_outline),
            color: AppColors.danger,
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
