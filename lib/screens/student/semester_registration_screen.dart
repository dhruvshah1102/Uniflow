import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/semester_registration.dart';
import '../../models/student_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/semester_registration_service.dart';

class SemesterRegistrationScreen extends StatefulWidget {
  const SemesterRegistrationScreen({super.key});

  @override
  State<SemesterRegistrationScreen> createState() => _SemesterRegistrationScreenState();
}

class _SemesterRegistrationScreenState extends State<SemesterRegistrationScreen> {
  final SemesterRegistrationService _service = SemesterRegistrationService.instance;
  Future<SemesterRegistrationContext>? _future;
  String? _boundFirebaseUid;
  final Set<String> _selectedCourseIds = <String>{};
  final Set<String> _backlogCourseIds = <String>{};
  bool _submitting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureLoaded();
  }

  void _ensureLoaded() {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    final student = auth.studentProfile;
    if (user == null || student == null) return;
    if (_future != null && _boundFirebaseUid == user.uidFirebase) return;

    _boundFirebaseUid = user.uidFirebase;
    _future = _loadContext(auth: auth, user: user, student: student);
  }

  Future<SemesterRegistrationContext> _loadContext({
    required AuthProvider auth,
    required UserModel user,
    required StudentModel student,
  }) async {
    final latestSemester = await _resolveLatestSemester(
      userId: user.id,
      fallback: student.semester,
    );
    return _service.loadStudentContext(
      studentId: student.userId,
      studentName: user.name,
      studentEmail: user.email,
      studentDepartment: student.department,
      currentSemester: latestSemester,
      creditLimit: 24,
    );
  }

  Future<void> _reload() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    final student = auth.studentProfile;
    if (user == null || student == null) return;

    setState(() {
      _boundFirebaseUid = user.uidFirebase;
      _future = _loadContext(auth: auth, user: user, student: student);
    });
    await _future;
  }

  Future<int> _resolveLatestSemester({
    required String userId,
    required int fallback,
  }) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final userSemester = _semesterFromData(userDoc.data());
    if (userSemester != null && userSemester > 0) return userSemester;
    final studentDoc = await FirebaseFirestore.instance.collection('students').doc(userId).get();
    final studentSemester = _semesterFromData(studentDoc.data());
    if (studentSemester != null && studentSemester > 0) return studentSemester;
    return fallback;
  }

  int? _semesterFromData(Map<String, dynamic>? data) {
    if (data == null) return null;
    final raw = data['semester'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  Future<void> _submit(SemesterRegistrationContext contextData) async {
    if (_submitting) return;

    setState(() => _submitting = true);
    try {
      await _service.submitRegistration(
        studentId: contextData.studentId,
        studentName: contextData.studentName,
        studentEmail: contextData.studentEmail,
        currentSemester: contextData.currentSemester,
        targetSemester: contextData.targetSemester,
        creditLimit: contextData.creditLimit,
        selectedCourseIds: _selectedCourseIds.toList(),
        backlogCourseIds: _backlogCourseIds.toList(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration request submitted successfully.')),
      );
      _selectedCourseIds.clear();
      _backlogCourseIds.clear();
      await _reload();
      setState(() {});
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

  int _totalSelectedCredits(
    List<RegistrationCourseOption> regularCourses,
    List<RegistrationCourseOption> backlogCourses,
  ) {
    final regular = _selectedCourseIds
        .where((id) => regularCourses.any((course) => course.id == id))
        .map((id) => regularCourses.firstWhere((course) => course.id == id))
        .toList();
    final backlog = _backlogCourseIds
        .where((id) => backlogCourses.any((course) => course.id == id))
        .map((id) => backlogCourses.firstWhere((course) => course.id == id))
        .toList();
    return [...regular, ...backlog].fold<int>(0, (total, course) => total + course.credits);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final mediaQuery = MediaQuery.of(context);

    if (auth.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.surfaceWarm,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (auth.currentUser == null || auth.studentProfile == null) {
      return Scaffold(
        backgroundColor: AppColors.surfaceWarm,
        appBar: AppBar(
          backgroundColor: AppColors.surfaceWarm,
          surfaceTintColor: Colors.transparent,
          title: const Text('Semester Registration'),
        ),
        body: const Center(child: Text('Student profile not available.')),
      );
    }

    _ensureLoaded();

    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: mediaQuery.textScaler.clamp(maxScaleFactor: 1.08),
      ),
      child: Scaffold(
        backgroundColor: AppColors.surfaceWarm,
        appBar: AppBar(
          backgroundColor: AppColors.surfaceWarm,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Semester Registration',
            style: TextStyle(
              color: AppColors.ink900,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: FutureBuilder<SemesterRegistrationContext>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _ErrorCard(
                    message: 'Unable to load registration data.',
                    details: snapshot.error.toString(),
                    onRetry: _reload,
                  ),
                ),
              );
            }

            final data = snapshot.data;
            if (data == null) {
              return const Center(child: Text('No registration data found.'));
            }

            final totalCredits = _totalSelectedCredits(
              data.availableCourses,
              data.backlogCourses,
            );
            final hasActiveRegistration = data.activeRegistration != null;
            final canSubmit = !_submitting &&
                data.registrationOpen &&
                !hasActiveRegistration &&
                _selectedCourseIds.isNotEmpty &&
                totalCredits <= data.creditLimit;

            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  const _SectionHeader(
                    eyebrow: 'SEMESTER REGISTRATION',
                    title: 'Register for next semester',
                    subtitle: 'Pick your regular courses and backlog subjects, then submit for admin approval.',
                  ),
                  const SizedBox(height: 16),
                  _InfoBanner(
                    title: 'Academic Status',
                    body:
                        'Current semester: ${data.currentSemester} | Next semester: ${data.targetSemester} | Credit limit: ${data.creditLimit}',
                  ),
                  if (!data.registrationOpen) ...[
                    const SizedBox(height: 16),
                    const _InfoBanner(
                      title: 'Registration Closed',
                      body: 'There is no active admin registration form for your next semester right now. Students can only register while the admin form is active.',
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (data.registrationOpen)
                    _SummaryCard(
                      selectedCourses: data.availableCourses
                          .where((course) => _selectedCourseIds.contains(course.id))
                          .toList(),
                      backlogCourses: data.backlogCourses
                          .where((course) => _backlogCourseIds.contains(course.id))
                          .toList(),
                      totalCredits: totalCredits,
                      creditLimit: data.creditLimit,
                    ),
                  if (hasActiveRegistration) ...[
                    const SizedBox(height: 16),
                    _PendingCard(record: data.activeRegistration!),
                  ],
                  const SizedBox(height: 16),
                  if (data.registrationOpen) ...[
                    _CourseSelectionSection(
                      title: 'Available Next Semester Courses',
                      subtitle: 'These courses share the same 24-credit limit with backlog choices.',
                      courses: data.availableCourses,
                      selectedIds: _selectedCourseIds,
                      enabled: !hasActiveRegistration && !_submitting,
                      onChanged: (courseId, selected) {
                        setState(() {
                          if (selected) {
                            _selectedCourseIds.add(courseId);
                            _backlogCourseIds.remove(courseId);
                          } else {
                            _selectedCourseIds.remove(courseId);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _CourseSelectionSection(
                      title: 'Backlog Courses',
                      subtitle: 'Choose backlog subjects instead of extra new courses within the same 24-credit limit.',
                      courses: data.backlogCourses,
                      selectedIds: _backlogCourseIds,
                      enabled: !hasActiveRegistration && !_submitting,
                      onChanged: (courseId, selected) {
                        setState(() {
                          if (selected) {
                            _backlogCourseIds.add(courseId);
                            _selectedCourseIds.remove(courseId);
                          } else {
                            _backlogCourseIds.remove(courseId);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  _ValidationCard(
                    totalCredits: totalCredits,
                    creditLimit: data.creditLimit,
                    selectedCount: _selectedCourseIds.length,
                    backlogCount: _backlogCourseIds.length,
                    pendingRegistration: hasActiveRegistration,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: canSubmit ? () => _submit(data) : null,
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_outlined),
                    label: Text(
                      hasActiveRegistration
                          ? data.activeRegistration!.status == 'approved'
                              ? 'Registration Approved'
                              : 'Pending Approval'
                          : totalCredits > data.creditLimit
                              ? 'Credit Limit Exceeded'
                              : 'Submit Registration',
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_outlined),
                    label: const Text('Back to Dashboard'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _RegistrationHistory(studentId: data.studentId),
                ],
              ),
            );
          },
        ),
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
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.ink900,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.ink500,
            height: 1.4,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String title;
  final String body;

  const _InfoBanner({
    required this.title,
    required this.body,
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
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.ink900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: AppColors.ink500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final List<RegistrationCourseOption> selectedCourses;
  final List<RegistrationCourseOption> backlogCourses;
  final int totalCredits;
  final int creditLimit;

  const _SummaryCard({
    required this.selectedCourses,
    required this.backlogCourses,
    required this.totalCredits,
    required this.creditLimit,
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
          const Text(
            'Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.ink900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Planned credits: $totalCredits / $creditLimit',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 12),
          _ChipGroup(
            title: 'Selected Courses',
            items: selectedCourses.map((course) => course.label).toList(),
          ),
          const SizedBox(height: 12),
          _ChipGroup(
            title: 'Backlog Courses',
            items: backlogCourses.map((course) => course.label).toList(),
          ),
        ],
      ),
    );
  }
}

class _ChipGroup extends StatelessWidget {
  final String title;
  final List<String> items;

  const _ChipGroup({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.ink700,
          ),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Text(
            'None selected',
            style: TextStyle(color: AppColors.ink500),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map(
                  (item) => Chip(
                    label: Text(
                      item,
                      overflow: TextOverflow.ellipsis,
                    ),
                    backgroundColor: AppColors.surfaceWarm,
                    side: const BorderSide(color: AppColors.border),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _CourseSelectionSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<RegistrationCourseOption> courses;
  final Set<String> selectedIds;
  final bool enabled;
  final void Function(String courseId, bool selected) onChanged;

  const _CourseSelectionSection({
    required this.title,
    required this.subtitle,
    required this.courses,
    required this.selectedIds,
    required this.enabled,
    required this.onChanged,
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.ink900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.ink500),
          ),
          const SizedBox(height: 12),
          if (courses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No courses available.',
                style: TextStyle(color: AppColors.ink500),
              ),
            )
          else
            ...courses.map(
              (course) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CheckboxListTile(
                  value: selectedIds.contains(course.id),
                  onChanged: enabled ? (value) => onChanged(course.id, value ?? false) : null,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: Text(
                    course.courseName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${course.courseCode} | ${course.credits} credits | Semester ${course.semester}',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ValidationCard extends StatelessWidget {
  final int totalCredits;
  final int creditLimit;
  final int selectedCount;
  final int backlogCount;
  final bool pendingRegistration;

  const _ValidationCard({
    required this.totalCredits,
    required this.creditLimit,
    required this.selectedCount,
    required this.backlogCount,
    required this.pendingRegistration,
  });

  @override
  Widget build(BuildContext context) {
    final exceeded = totalCredits > creditLimit;
    final message = pendingRegistration
        ? 'You already have an active registration for the next semester.'
        : exceeded
            ? 'Selected credits exceed the allowed limit.'
            : 'Your selection is valid and ready for submission.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: exceeded ? AppColors.danger.withOpacity(0.08) : AppColors.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: exceeded ? AppColors.danger.withOpacity(0.2) : AppColors.success.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Validation',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: exceeded ? AppColors.danger : AppColors.success,
            ),
          ),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(color: AppColors.ink700)),
          const SizedBox(height: 10),
          Text('Selected courses: $selectedCount', style: const TextStyle(color: AppColors.ink700)),
          Text('Backlog courses: $backlogCount', style: const TextStyle(color: AppColors.ink700)),
          Text('Total selected credits: $totalCredits / $creditLimit', style: const TextStyle(color: AppColors.ink700)),
        ],
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  final SemesterRegistrationRecord record;

  const _PendingCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final approved = record.status == 'approved';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (approved ? AppColors.success : AppColors.warning).withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (approved ? AppColors.success : AppColors.warning).withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            approved ? 'Registration Approved' : 'Pending Approval',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.ink900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            approved
                ? 'Courses approved for Semester ${record.targetSemester} will now be added to active enrollments and your semester will advance.'
                : 'Submitted on your behalf for Semester ${record.targetSemester}.',
            style: const TextStyle(
              color: AppColors.ink700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Status: ${record.status.toUpperCase()}',
            style: const TextStyle(color: AppColors.ink700),
          ),
        ],
      ),
    );
  }
}

class _RegistrationHistory extends StatelessWidget {
  final String studentId;

  const _RegistrationHistory({required this.studentId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SemesterRegistrationRecord>>(
      stream: SemesterRegistrationService.instance.streamRegistrations(studentId: studentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _ErrorCard(
            message: 'Unable to load your registration history.',
            details: snapshot.error.toString(),
            onRetry: () async {},
          );
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Requests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink900,
              ),
            ),
            const SizedBox(height: 12),
            ...items.map(
              (record) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _HistoryCard(record: record),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final SemesterRegistrationRecord record;

  const _HistoryCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final color = switch (record.status) {
      'approved' => AppColors.success,
      'rejected' => AppColors.danger,
      _ => AppColors.warning,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Semester ${record.targetSemester}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink900,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  record.status.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Selected: ${record.selectedCourseNames.join(', ')}',
            style: const TextStyle(color: AppColors.ink500),
          ),
          if (record.backlogCourseNames.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Backlogs: ${record.backlogCourseNames.join(', ')}',
              style: const TextStyle(color: AppColors.ink500),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Credits: ${record.totalCredits}/${record.creditLimit}',
            style: const TextStyle(color: AppColors.ink500),
          ),
          if (record.rejectionReason != null && record.rejectionReason!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Reason: ${record.rejectionReason}',
              style: const TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final String details;
  final Future<void> Function() onRetry;

  const _ErrorCard({
    required this.message,
    required this.details,
    required this.onRetry,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 44),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            details,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.ink500),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
