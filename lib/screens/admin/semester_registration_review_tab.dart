import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/admin_module_service.dart';
import '../../models/semester_registration.dart';
import '../../models/semester_registration_form.dart';
import '../../services/semester_registration_service.dart';

class SemesterRegistrationReviewTab extends StatefulWidget {
  final String adminId;
  final Future<void> Function() onChanged;

  const SemesterRegistrationReviewTab({
    super.key,
    required this.adminId,
    required this.onChanged,
  });

  @override
  State<SemesterRegistrationReviewTab> createState() => _SemesterRegistrationReviewTabState();
}

class _SemesterRegistrationReviewTabState extends State<SemesterRegistrationReviewTab> {
  final _formSemesterController = TextEditingController(text: '2');
  final _formDepartmentController = TextEditingController(text: 'CSE');
  late final Future<void> _catalogReady;
  bool _creatingForm = false;

  @override
  void initState() {
    super.initState();
    _catalogReady = AdminModuleService.instance.ensureCourseCatalog();
  }

  @override
  void dispose() {
    _formSemesterController.dispose();
    _formDepartmentController.dispose();
    super.dispose();
  }

  Future<void> _createForm(List<String> availableCourseIds, List<String> backlogCourseIds) async {
    if (_creatingForm) return;
    final semester = int.tryParse(_formSemesterController.text.trim());
    if (semester == null || semester < 1 || semester > 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid semester between 1 and 12.')),
      );
      return;
    }

    setState(() => _creatingForm = true);
    try {
      await SemesterRegistrationService.instance.createRegistrationForm(
        semester: semester,
        department: _formDepartmentController.text.trim(),
        availableCourseIds: availableCourseIds,
        backlogCourseIds: backlogCourseIds,
        createdBy: widget.adminId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration form created for Semester $semester.')),
      );
      await widget.onChanged();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _creatingForm = false);
    }
  }

  Future<void> _reject(BuildContext context, SemesterRegistrationRecord record) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reject Registration'),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Rejection reason',
              hintText: 'Explain why the request is being rejected',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(reasonController.text.trim()),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    if (reason == null) return;
    await SemesterRegistrationService.instance.reviewRegistration(
      registrationId: record.id,
      adminId: widget.adminId,
      approve: false,
      rejectionReason: reason,
    );
    await widget.onChanged();
  }

  Future<void> _approve(SemesterRegistrationRecord record) async {
    await SemesterRegistrationService.instance.reviewRegistration(
      registrationId: record.id,
      adminId: widget.adminId,
      approve: true,
    );
    await widget.onChanged();
  }

  Future<void> _resetCycle(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reset upcoming registration cycle?'),
          content: const Text(
            'This clears semester registration forms, requests, and upcoming enrollments while keeping current enrollments unchanged.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await SemesterRegistrationService.instance.resetUpcomingRegistrationCycle();
    await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _catalogReady,
      builder: (context, catalogSnapshot) {
        if (catalogSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (catalogSnapshot.hasError) {
          return Center(child: Text(catalogSnapshot.error.toString(), textAlign: TextAlign.center));
        }

        return StreamBuilder<List<SemesterRegistrationForm>>(
          stream: SemesterRegistrationService.instance.streamRegistrationForms(activeOnly: false),
          builder: (context, formSnapshot) {
            return StreamBuilder<List<SemesterRegistrationRecord>>(
              stream: SemesterRegistrationService.instance.streamPendingRegistrations(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text(snapshot.error.toString(), textAlign: TextAlign.center));
                }

                final items = snapshot.data ?? [];
                final forms = formSnapshot.data ?? [];
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    _FormCreatorCard(
                      semesterController: _formSemesterController,
                      departmentController: _formDepartmentController,
                      creating: _creatingForm,
                      onCreate: _createForm,
                    ),
                    const SizedBox(height: 12),
                    if (forms.isNotEmpty) _RegistrationFormsCard(forms: forms),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () => _resetCycle(context),
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Reset Upcoming Cycle'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (items.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 36),
                          child: Text('No pending semester registrations.'),
                        ),
                      )
                    else
                      ...items.map(
                        (record) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border),
                            ),
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
                                            record.studentName.isNotEmpty ? record.studentName : record.studentId,
                                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink900),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            record.studentEmail.isNotEmpty ? record.studentEmail : record.studentId,
                                            style: const TextStyle(color: AppColors.ink500),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.warning.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        'Semester ${record.targetSemester}',
                                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.warning, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text('Selected courses: ${record.selectedCourseNames.isEmpty ? record.selectedCourseIds.join(', ') : record.selectedCourseNames.join(', ')}'),
                                const SizedBox(height: 6),
                                Text('Backlog courses: ${record.backlogCourseNames.isEmpty ? 'None' : record.backlogCourseNames.join(', ')}'),
                                const SizedBox(height: 6),
                                Text('Credits: ${record.totalCredits}/${record.creditLimit}'),
                                if (record.totalCredits > record.creditLimit) ...[
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Validation warning: credit limit exceeded.',
                                    style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _reject(context, record),
                                        icon: const Icon(Icons.close),
                                        label: const Text('Reject'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: () => _approve(record),
                                        icon: const Icon(Icons.check),
                                        label: const Text('Approve'),
                                      ),
                                    ),
                                  ],
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
        );
      },
    );
  }
}

class _FormCreatorCard extends StatelessWidget {
  final TextEditingController semesterController;
  final TextEditingController departmentController;
  final bool creating;
  final Future<void> Function(List<String> availableCourseIds, List<String> backlogCourseIds) onCreate;

  const _FormCreatorCard({
    required this.semesterController,
    required this.departmentController,
    required this.creating,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return _FormCreatorPanel(
      semesterController: semesterController,
      departmentController: departmentController,
      creating: creating,
      onCreate: onCreate,
    );
  }
}

class _FormCreatorPanel extends StatefulWidget {
  final TextEditingController semesterController;
  final TextEditingController departmentController;
  final bool creating;
  final Future<void> Function(List<String> availableCourseIds, List<String> backlogCourseIds) onCreate;

  const _FormCreatorPanel({
    required this.semesterController,
    required this.departmentController,
    required this.creating,
    required this.onCreate,
  });

  @override
  State<_FormCreatorPanel> createState() => _FormCreatorPanelState();
}

class _FormCreatorPanelState extends State<_FormCreatorPanel> {
  final Set<String> _availableSelected = <String>{};
  final Set<String> _backlogSelected = <String>{};
  String? _prefilledContextKey;

  @override
  void initState() {
    super.initState();
    widget.semesterController.addListener(_handleInputsChanged);
    widget.departmentController.addListener(_handleInputsChanged);
  }

  @override
  void dispose() {
    widget.semesterController.removeListener(_handleInputsChanged);
    widget.departmentController.removeListener(_handleInputsChanged);
    super.dispose();
  }

  void _handleInputsChanged() {
    if (mounted) setState(() {});
  }

  int _semesterValue() => int.tryParse(widget.semesterController.text.trim()) ?? 0;

  bool _matchesDepartment(String courseDepartment) {
    final filter = widget.departmentController.text.trim().toLowerCase();
    final dept = courseDepartment.trim().toLowerCase();
    if (filter.isEmpty || dept.isEmpty) return true;
    return filter == dept;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: StreamBuilder<List<AdminCourseItem>>(
        stream: AdminModuleService.instance.streamCourses(),
      builder: (context, snapshot) {
          final semester = _semesterValue();
          final nextSemesterCourses = semester > 0 ? semester : 1;
          final contextKey = 'sem:$nextSemesterCourses|dept:${widget.departmentController.text.trim().toLowerCase()}';
          final allCourses = snapshot.data ?? const <AdminCourseItem>[];
          final available = allCourses
              .where((course) => course.semesterNumber == nextSemesterCourses)
              .where((course) => _matchesDepartment(course.department))
              .toList()
            ..sort((a, b) => a.code.toLowerCase().compareTo(b.code.toLowerCase()));
          final backlog = allCourses
              .where((course) => course.semesterNumber > 0 && course.semesterNumber < nextSemesterCourses)
              .where((course) => _matchesDepartment(course.department))
              .toList()
            ..sort((a, b) => a.semesterNumber != b.semesterNumber
                ? a.semesterNumber.compareTo(b.semesterNumber)
                : a.code.toLowerCase().compareTo(b.code.toLowerCase()));

          final availableVisibleIds = available.map((course) => course.id).toSet();
          final backlogVisibleIds = backlog.map((course) => course.id).toSet();

          if (_prefilledContextKey != contextKey) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _availableSelected
                  ..clear()
                  ..addAll(availableVisibleIds);
                _backlogSelected
                  ..clear()
                  ..addAll(backlogVisibleIds);
                _prefilledContextKey = contextKey;
              });
            });
          }

          final filteredAvailable = _availableSelected.where(availableVisibleIds.contains).toList();
          final filteredBacklog = _backlogSelected.where(backlogVisibleIds.contains).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create Registration Form',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select the active semester courses and the backlog pool. Students will only see what is checked here.',
                style: TextStyle(color: AppColors.ink500),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.semesterController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Target Semester'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: widget.departmentController,
                      decoration: const InputDecoration(labelText: 'Department'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SelectableCourseSection(
                title: 'Available Courses',
                subtitle: 'Semester $nextSemesterCourses courses visible to students.',
                emptyText: snapshot.connectionState == ConnectionState.waiting
                    ? 'Loading course catalog...'
                    : 'No courses found for this semester.',
                courses: available,
                selectedIds: filteredAvailable.toSet(),
                onChanged: (courseId, selected) {
                  setState(() {
                    if (selected) {
                      _availableSelected.add(courseId);
                    } else {
                      _availableSelected.remove(courseId);
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              _SelectableCourseSection(
                title: 'Backlog Courses',
                subtitle: 'Previous semesters offered for backlog registration.',
                emptyText: snapshot.connectionState == ConnectionState.waiting
                    ? 'Loading course catalog...'
                    : 'No backlog courses found.',
                courses: backlog,
                selectedIds: filteredBacklog.toSet(),
                onChanged: (courseId, selected) {
                  setState(() {
                    if (selected) {
                      _backlogSelected.add(courseId);
                    } else {
                      _backlogSelected.remove(courseId);
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.creating
                      ? null
                      : () async {
                          await widget.onCreate(
                            filteredAvailable,
                            filteredBacklog,
                          );
                        },
                  icon: widget.creating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.playlist_add_check),
                  label: Text(widget.creating ? 'Creating...' : 'Create Form'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SelectableCourseSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final String emptyText;
  final List<AdminCourseItem> courses;
  final Set<String> selectedIds;
  final void Function(String courseId, bool selected) onChanged;

  const _SelectableCourseSection({
    required this.title,
    required this.subtitle,
    required this.emptyText,
    required this.courses,
    required this.selectedIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink900)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: AppColors.ink500, fontSize: 13)),
          const SizedBox(height: 10),
          if (courses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(emptyText, style: const TextStyle(color: AppColors.ink500)),
            )
          else
            ...courses.map(
              (course) => CheckboxListTile(
                value: selectedIds.contains(course.id),
                onChanged: (value) => onChanged(course.id, value ?? false),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text('${course.code} - ${course.courseName}'),
                subtitle: Text('Semester ${course.semesterNumber} | ${course.department.isEmpty ? 'All departments' : course.department}'),
              ),
            ),
        ],
      ),
    );
  }
}

class _RegistrationFormsCard extends StatelessWidget {
  final List<SemesterRegistrationForm> forms;

  const _RegistrationFormsCard({required this.forms});

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
          const Text(
            'Registration Forms',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink900),
          ),
          const SizedBox(height: 10),
          ...forms.map(
            (form) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: form.active ? AppColors.success.withValues(alpha: 0.12) : AppColors.ink100,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Semester ${form.semester}',
                      style: TextStyle(
                        color: form.active ? AppColors.success : AppColors.ink500,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${form.department.isEmpty ? 'All departments' : form.department} | ${form.availableCourseIds.length} courses',
                      style: const TextStyle(color: AppColors.ink700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
