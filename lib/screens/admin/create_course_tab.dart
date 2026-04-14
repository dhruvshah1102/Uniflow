import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/admin_module_service.dart';

class CreateCourseTab extends StatefulWidget {
  final AdminModuleService service;
  final Future<void> Function() onChanged;

  const CreateCourseTab({
    super.key,
    required this.service,
    required this.onChanged,
  });

  @override
  State<CreateCourseTab> createState() => _CreateCourseTabState();
}

class _CreateCourseTabState extends State<CreateCourseTab> {
  final _formKey = GlobalKey<FormState>();
  final _courseNameCtrl = TextEditingController();
  final _courseCodeCtrl = TextEditingController();
  final _creditsCtrl = TextEditingController(text: '3');
  final _semesterCtrl = TextEditingController(text: '5');

  Future<List<AdminUserItem>>? _facultyFuture;
  String? _facultyId;
  bool _submitting = false;
  String? _deletingCourseId;

  @override
  void initState() {
    super.initState();
    _facultyFuture = widget.service.fetchFacultyUsers();
  }

  @override
  void dispose() {
    _courseNameCtrl.dispose();
    _courseCodeCtrl.dispose();
    _creditsCtrl.dispose();
    _semesterCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(List<AdminUserItem> faculty) async {
    if (!_formKey.currentState!.validate()) return;
    if (_facultyId == null || _facultyId!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a faculty member.')));
      return;
    }

    final facultyItem = faculty.where((item) => item.uidFirebase == _facultyId || item.id == _facultyId).isNotEmpty
        ? faculty.firstWhere((item) => item.uidFirebase == _facultyId || item.id == _facultyId)
        : null;
    if (facultyItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selected faculty could not be found.')));
      return;
    }

    final credits = int.tryParse(_creditsCtrl.text.trim()) ?? 0;
    if (credits < 1 || credits > 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Credits must be between 1 and 5.')));
      return;
    }

    final semester = int.tryParse(_semesterCtrl.text.trim()) ?? 0;
    if (semester < 1 || semester > 12) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Semester must be between 1 and 12.')));
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.service.createCourse(
        courseName: _courseNameCtrl.text.trim(),
        courseCode: _courseCodeCtrl.text.trim(),
        credits: credits,
        semester: semester,
        department: facultyItem.department == '-' ? 'CSE' : facultyItem.department,
        facultyId: facultyItem.uidFirebase,
        facultyName: facultyItem.name,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course created successfully.')),
      );
      _courseNameCtrl.clear();
      _courseCodeCtrl.clear();
      _creditsCtrl.text = '3';
      _semesterCtrl.text = '5';
      setState(() => _facultyId = null);
      await widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _deleteCourse(AdminCourseItem course) async {
    if (_deletingCourseId != null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete course?'),
        content: Text(
          'This will permanently delete ${course.courseName} and its related assignments, quizzes, materials, enrollments, and results.',
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

    setState(() => _deletingCourseId = course.id);
    try {
      await widget.service.deleteCourse(course.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${course.courseName} deleted successfully.')),
      );
      await widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _deletingCourseId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminUserItem>>(
      future: _facultyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString(), textAlign: TextAlign.center));
        }

        final faculty = snapshot.data ?? [];
        final canSubmit = !_submitting &&
            _courseNameCtrl.text.trim().isNotEmpty &&
            _courseCodeCtrl.text.trim().isNotEmpty &&
            int.tryParse(_creditsCtrl.text.trim()) != null &&
            int.tryParse(_semesterCtrl.text.trim()) != null &&
            (_facultyId != null && _facultyId!.trim().isNotEmpty);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          children: [
            const Text(
              'CREATE COURSE',
              style: TextStyle(color: AppColors.primaryDark, letterSpacing: 1.2, fontWeight: FontWeight.w700, fontSize: 11),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create Course',
              style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w800, fontSize: 36, height: 1.05),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a course once and let it flow into faculty teaching assignments and student registration.',
              style: TextStyle(color: AppColors.ink700, height: 1.35),
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _courseNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Course Name',
                        hintText: 'Data Structures',
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Course name is required.';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _courseCodeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Course Code',
                        hintText: 'CSE101',
                      ),
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.characters,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Course code is required.';
                        }
                        if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(value.trim())) {
                          return 'Use letters and numbers only.';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _creditsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Credits',
                        hintText: '3',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final credits = int.tryParse((value ?? '').trim());
                        if (credits == null) return 'Enter a valid credit value.';
                        if (credits < 1 || credits > 5) return 'Credits must be between 1 and 5.';
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _semesterCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Semester Offered',
                        hintText: '5',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final semester = int.tryParse((value ?? '').trim());
                        if (semester == null) return 'Enter a valid semester.';
                        if (semester < 1 || semester > 12) return 'Semester must be between 1 and 12.';
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _facultyId,
                      decoration: const InputDecoration(
                        labelText: 'Faculty Selection',
                      ),
                      items: faculty
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item.uidFirebase,
                              child: Text(item.name),
                            ),
                          )
                          .toList(),
                      onChanged: faculty.isEmpty ? null : (value) => setState(() => _facultyId = value),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Select a faculty member.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: canSubmit ? () => _submit(faculty) : null,
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.add),
                        label: const Text('Create Course'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Live Course List',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink900),
            ),
            const SizedBox(height: 10),
            StreamBuilder<List<AdminCourseItem>>(
              stream: widget.service.streamCourses(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Text(snapshot.error.toString(), textAlign: TextAlign.center);
                }

                final courses = snapshot.data ?? [];
                if (courses.isEmpty) {
                  return const Text('No courses available yet.');
                }

                return Column(
                  children: courses
                      .map(
                        (course) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppColors.primaryDark.withValues(alpha: 0.12),
                                  child: Text(course.code.isNotEmpty ? course.code[0] : '?', style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(course.courseName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${course.code} • ${course.credits} credits • ${course.semester}',
                                        style: const TextStyle(color: AppColors.ink500),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: 'Delete course',
                                  onPressed: _deletingCourseId == course.id ? null : () => _deleteCourse(course),
                                  icon: _deletingCourseId == course.id
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.delete_outline),
                                  color: AppColors.danger,
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
