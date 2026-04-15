import 'package:flutter/foundation.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/semester_registration.dart';
import '../models/semester_registration_form.dart';
import '../services/admin_module_service.dart';

class SemesterRegistrationService {
  SemesterRegistrationService._();

  static final SemesterRegistrationService instance = SemesterRegistrationService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<SemesterRegistrationContext> loadStudentContext({
    required String studentId,
    required String studentName,
    required String studentEmail,
    required String studentDepartment,
    required int currentSemester,
    int creditLimit = 24,
  }) async {
    await AdminModuleService.instance.seedInitialSemesterEnrollments(
      studentId: studentId,
      department: studentDepartment,
    );
    await AdminModuleService.instance.ensureCourseCatalog();
    final courseOptions = await _fetchCourseOptions();
    final enrollments = await _fetchEnrollmentCourseIds(studentId);
    final upcomingEnrollments = await _fetchUpcomingEnrollmentCourseIds(studentId);
    final registrations = await _fetchRegistrations(studentId);
    final activeForm = await _fetchActiveForm(
      semester: currentSemester + 1,
      department: studentDepartment,
    );
    final targetSemester = activeForm?.semester ?? currentSemester + 1;
    final registrationOpen = activeForm != null;

    final activeRegistration = registrations
        .where((record) => record.targetSemester == targetSemester && (record.status == 'pending' || record.status == 'approved'))
        .fold<SemesterRegistrationRecord?>(null, (previous, record) {
          if (previous == null) return record;
          return record.createdAt.compareTo(previous.createdAt) > 0 ? record : previous;
        });

    final allowedCourseIds = registrationOpen
        ? activeForm!.availableCourseIds.toSet()
        : <String>{};
    final allowedBacklogIds = registrationOpen
        ? activeForm!.backlogCourseIds.toSet()
        : <String>{};
    final availableCourses = registrationOpen
        ? (() {
            final list = courseOptions
                .where((course) => course.semester == targetSemester && _matchesDepartment(course.department, studentDepartment))
                .where((course) => allowedCourseIds.isEmpty || allowedCourseIds.contains(course.id))
                .where((course) => !enrollments.contains(course.id))
                .where((course) => !upcomingEnrollments.contains(course.id))
                .toList();
            list.sort((a, b) => a.courseCode.toLowerCase().compareTo(b.courseCode.toLowerCase()));
            return list;
          })()
        : <RegistrationCourseOption>[];

    final backlogCourses = registrationOpen
        ? (() {
            final list = courseOptions
                .where((course) => course.semester > 0 && course.semester < targetSemester && _matchesDepartment(course.department, studentDepartment))
                .where((course) => allowedBacklogIds.isEmpty || allowedBacklogIds.contains(course.id))
                .where((course) => !upcomingEnrollments.contains(course.id))
                .toList();
            list.sort((a, b) => a.courseCode.toLowerCase().compareTo(b.courseCode.toLowerCase()));
            return list;
          })()
        : <RegistrationCourseOption>[];

    return SemesterRegistrationContext(
      studentId: studentId,
      studentName: studentName,
      studentEmail: studentEmail,
      currentSemester: currentSemester,
      targetSemester: targetSemester,
      creditLimit: creditLimit,
      registrationOpen: registrationOpen,
      availableCourses: availableCourses,
      backlogCourses: backlogCourses,
      enrolledCourseIds: enrollments,
      upcomingCourseIds: upcomingEnrollments,
      activeRegistration: activeRegistration,
    );
  }

  Stream<List<SemesterRegistrationForm>> streamRegistrationForms({bool activeOnly = true}) {
    return _db.collection('registrationForms').snapshots().map((snap) {
      final forms = snap.docs.map((doc) => SemesterRegistrationForm.fromMap(doc.data(), doc.id)).toList();
      final filtered = activeOnly ? forms.where((form) => form.active).toList() : forms;
      filtered.sort((a, b) {
        final semesterCompare = a.semester.compareTo(b.semester);
        if (semesterCompare != 0) return semesterCompare;
        return b.createdAt.compareTo(a.createdAt);
      });
      return filtered;
    });
  }

  Future<SemesterRegistrationForm?> createRegistrationForm({
    required int semester,
    required String department,
    required List<String> availableCourseIds,
    required List<String> backlogCourseIds,
    bool active = true,
    String? createdBy,
  }) async {
    if (semester < 1 || semester > 12) {
      throw Exception('Choose a valid semester between 1 and 12.');
    }

    await AdminModuleService.instance.fetchOverview();
    final courses = await _fetchCourseOptions();
    final allowedAvailableCourseIds = _courseIdsForSemester(
      courseOptions: courses,
      semester: semester,
      department: department,
    );
    final allowedBacklogCourseIds = _courseIdsForBacklog(
      courseOptions: courses,
      semester: semester,
      department: department,
    );

    final normalizedAvailable = _normalizeIds(availableCourseIds);
    final normalizedBacklog = _normalizeIds(backlogCourseIds);
    final selectedAvailableCourseIds = normalizedAvailable.isEmpty ? allowedAvailableCourseIds : normalizedAvailable.where((id) => allowedAvailableCourseIds.contains(id)).toList();
    final selectedBacklogCourseIds = normalizedBacklog.isEmpty
        ? allowedBacklogCourseIds
        : normalizedBacklog.where((id) => allowedBacklogCourseIds.contains(id)).toList();

    if (selectedAvailableCourseIds.isEmpty) {
      throw Exception('Select at least one available course for the form.');
    }

    final formDoc = _db.collection('registrationForms').doc();
    final form = SemesterRegistrationForm(
      id: formDoc.id,
      semester: semester,
      department: department.trim(),
      availableCourseIds: selectedAvailableCourseIds,
      backlogCourseIds: selectedBacklogCourseIds,
      active: active,
      createdAt: Timestamp.now(),
      createdBy: createdBy,
    );
    await formDoc.set(form.toMap());
    return form;
  }

  Stream<List<SemesterRegistrationRecord>> streamRegistrations({String? studentId}) {
    Query<Map<String, dynamic>> query = _db.collection('registrations');
    if (studentId != null && studentId.trim().isNotEmpty) {
      query = query.where('studentId', isEqualTo: studentId.trim());
    }
    return query.snapshots().map((snap) {
      final records = snap.docs.map((doc) => SemesterRegistrationRecord.fromMap(doc.data(), doc.id)).toList();
      records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return records;
    });
  }

  Stream<List<SemesterRegistrationRecord>> streamPendingRegistrations() {
    return streamRegistrations().map((records) => records.where((record) => record.status == 'pending').toList());
  }

  Future<bool> isRegistrationOpen({
    required int semester,
    required String department,
  }) async {
    final form = await _fetchActiveForm(semester: semester, department: department);
    return form != null;
  }

  Future<String> submitRegistration({
    required String studentId,
    required String studentName,
    required String studentEmail,
    required int currentSemester,
    required int targetSemester,
    required int creditLimit,
    required List<String> selectedCourseIds,
    required List<String> backlogCourseIds,
    String? registrationFormId,
  }) async {
    final normalizedSelected = _normalizeIds(selectedCourseIds);
    final normalizedBacklog = _normalizeIds(backlogCourseIds);
    final allowedForm = await _fetchActiveForm(semester: targetSemester, department: '');
    if (allowedForm == null) {
      throw Exception('Registration is currently closed for this semester.');
    }
    if (allowedForm.semester != targetSemester) {
      throw Exception('This registration form is not open for the selected semester.');
    }

    final allowedCourseIds = allowedForm.availableCourseIds.toSet();
    final allowedBacklogIds = allowedForm.backlogCourseIds.toSet();

    if (normalizedSelected.isEmpty) {
      throw Exception('Please select at least one course.');
    }

    if (normalizedSelected.any(normalizedBacklog.contains)) {
      throw Exception('A course cannot be selected as both regular and backlog.');
    }

    final courseMap = await _fetchCourseMap([...normalizedSelected, ...normalizedBacklog]);
    final selectedCourses = normalizedSelected.map((id) => courseMap[id]).toList();
    final backlogCourses = normalizedBacklog.map((id) => courseMap[id]).toList();

    if (selectedCourses.any((course) => course == null) || backlogCourses.any((course) => course == null)) {
      throw Exception('One or more selected courses are no longer available.');
    }

    final selected = selectedCourses.whereType<RegistrationCourseOption>().toList();
    final backlog = backlogCourses.whereType<RegistrationCourseOption>().toList();

    if (selected.any((course) => course.semester != targetSemester)) {
      throw Exception('Selected courses must belong to the next semester.');
    }

    if (allowedCourseIds.isNotEmpty && selected.any((course) => !allowedCourseIds.contains(course.id))) {
      throw Exception('Selected courses are not part of the active registration form.');
    }

    if (allowedBacklogIds.isNotEmpty && backlog.any((course) => !allowedBacklogIds.contains(course.id))) {
      throw Exception('Backlog courses are not part of the active registration form.');
    }

    if (backlog.any((course) => course.semester >= targetSemester)) {
      throw Exception('Backlog courses must be from a previous semester.');
    }

    final totalCredits = [
      ...selected,
      ...backlog,
    ].fold<int>(0, (total, course) => total + course.credits);
    if (totalCredits > creditLimit) {
      throw Exception('Selected credits exceed the maximum limit of $creditLimit.');
    }

    final existingRegistrations = await _db.collection('registrations').where('studentId', isEqualTo: studentId).get();
    final hasPending = existingRegistrations.docs.any((doc) {
      final record = SemesterRegistrationRecord.fromMap(doc.data(), doc.id);
      return record.targetSemester == targetSemester && record.status == 'pending';
    });
    if (hasPending) {
      throw Exception('You already have a pending registration for the next semester.');
    }

    final hasApproved = existingRegistrations.docs.any((doc) {
      final record = SemesterRegistrationRecord.fromMap(doc.data(), doc.id);
      return record.targetSemester == targetSemester && record.status == 'approved';
    });
    if (hasApproved) {
      throw Exception('An approved registration already exists for this semester.');
    }

    final docRef = _db.collection('registrations').doc();
    final data = <String, dynamic>{
      'studentId': studentId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'currentSemester': currentSemester,
      'targetSemester': targetSemester,
      'creditLimit': creditLimit,
      'selectedCourses': normalizedSelected,
      'selectedCourseNames': selected.map((course) => course.label).toList(),
      'backlogCourses': normalizedBacklog,
      'backlogCourseNames': backlog.map((course) => course.label).toList(),
      'totalCredits': totalCredits,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'registrationType': 'semester_registration',
    };
    if (registrationFormId != null) {
      data['registrationFormId'] = registrationFormId;
    }
    await docRef.set(data);
    return docRef.id;
  }

  Future<void> reviewRegistration({
    required String registrationId,
    required String adminId,
    required bool approve,
    String? rejectionReason,
  }) async {
    try {
      final regRef = _db.collection('registrations').doc(registrationId);
      final regSnap = await regRef.get();
      if (!regSnap.exists || regSnap.data() == null) {
        throw Exception('Registration request not found.');
      }

      final record = SemesterRegistrationRecord.fromMap(regSnap.data()!, regSnap.id);
      if (record.status != 'pending') {
        throw Exception('This request has already been reviewed.');
      }

      if (record.studentId.isEmpty) {
        throw Exception('Registration request is missing a student identifier.');
      }

      if (record.targetSemester < 1 || record.targetSemester > 12) {
        throw Exception('Registration request has an invalid target semester.');
      }

      if (!approve && (rejectionReason == null || rejectionReason.trim().isEmpty)) {
        throw Exception('Please provide a rejection reason.');
      }

      final courseIds = {
        ...record.selectedCourseIds.where((id) => id.trim().isNotEmpty),
        ...record.backlogCourseIds.where((id) => id.trim().isNotEmpty),
      }.toList();
      if (approve && courseIds.isEmpty) {
        throw Exception('Cannot approve registration without any selected or backlog courses.');
      }

      final batch = _db.batch();

      if (approve) {
        debugPrint('reviewRegistration approving registration ${record.id} for student ${record.studentId}');
        for (final courseId in courseIds) {
          final safeStudentId = Uri.encodeComponent(record.studentId);
          final safeCourseId = Uri.encodeComponent(courseId);
          batch.delete(_db.collection('upcomingEnrollments').doc('upcoming_${safeStudentId}_$safeCourseId'));
          batch.set(
            _db.collection('enrollments').doc('enr_${safeStudentId}_$safeCourseId'),
            {
              'studentId': record.studentId,
              'courseId': courseId,
              'semester': record.targetSemester,
              'status': 'active',
              'registrationId': record.id,
              'approvedAt': FieldValue.serverTimestamp(),
              'approvedBy': adminId,
            },
            SetOptions(merge: true),
          );
        }

        batch.set(
          _db.collection('users').doc(record.studentId),
          {
            'semester': record.targetSemester,
            'updated_at': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        batch.set(
          _db.collection('students').doc(record.studentId),
          {
            'semester': record.targetSemester,
            'updated_at': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      batch.set(
        regRef,
        {
          'status': approve ? 'approved' : 'rejected',
          'reviewedBy': adminId,
          'reviewedAt': FieldValue.serverTimestamp(),
          if (!approve) 'rejectionReason': rejectionReason?.trim(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      try {
        await _db.collection('notifications').add(
          {
            'userId': record.studentId,
            'title': approve ? 'Registration Approved' : 'Registration Rejected',
            'message': approve
                ? 'Your next semester registration has been approved.'
                : 'Your next semester registration has been rejected.',
            'body': approve
                ? 'Your next semester registration has been approved.'
                : 'Your next semester registration has been rejected.',
            'type': 'registration',
            'read': false,
            'createdBy': adminId,
            'createdAt': FieldValue.serverTimestamp(),
          },
        );
      } catch (notificationError, notificationStack) {
        debugPrint('reviewRegistration notification write failed: $notificationError');
        debugPrintStack(stackTrace: notificationStack);
      }
    } on FirebaseException catch (e) {
      debugPrint('reviewRegistration FirebaseException: $e');
      debugPrintStack(stackTrace: e.stackTrace);
      throw Exception('Failed to review registration: ${e.message ?? e.code}');
    } catch (e, stack) {
      debugPrint('reviewRegistration failed: $e');
      debugPrintStack(stackTrace: stack);
      rethrow;
    }
  }

  Future<void> resetUpcomingRegistrationCycle() async {
    final registrationsSnap = await _db.collection('registrations').get();
    final upcomingSnap = await _db.collection('upcomingEnrollments').get();
    final formsSnap = await _db.collection('registrationForms').get();

    final registrationRefs = registrationsSnap.docs
        .where((doc) {
          final data = doc.data();
          return data['targetSemester'] != null || data['registrationType'] == 'semester_registration';
        })
        .map((doc) => doc.reference)
        .toList();
    final upcomingRefs = upcomingSnap.docs.map((doc) => doc.reference).toList();
    final formRefs = formsSnap.docs.map((doc) => doc.reference).toList();

    await _deleteRefs([...registrationRefs, ...upcomingRefs, ...formRefs]);
  }

  Future<List<RegistrationCourseOption>> _fetchCourseOptions() async {
    final snap = await _db.collection('courses').get();
    return snap.docs
        .map((doc) => RegistrationCourseOption.fromMap(doc.data(), doc.id))
        .where((course) => course.courseName.trim().isNotEmpty)
        .toList();
  }

  List<String> _courseIdsForSemester({
    required List<RegistrationCourseOption> courseOptions,
    required int semester,
    required String department,
  }) {
    return courseOptions
        .where((course) => course.semester == semester && _matchesDepartment(course.department, department))
        .map((course) => course.id)
        .toSet()
        .toList();
  }

  List<String> _courseIdsForBacklog({
    required List<RegistrationCourseOption> courseOptions,
    required int semester,
    required String department,
  }) {
    return courseOptions
        .where((course) => course.semester > 0 && course.semester < semester && _matchesDepartment(course.department, department))
        .map((course) => course.id)
        .toSet()
        .toList();
  }

  Future<List<String>> _fetchEnrollmentCourseIds(String studentId) async {
    final snap = await _db.collection('enrollments').where('studentId', isEqualTo: studentId).get();
    return snap.docs
        .map((doc) => _string(doc.data()['courseId']))
        .whereType<String>()
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
  }

  Future<List<String>> _fetchUpcomingEnrollmentCourseIds(String studentId) async {
    final snap = await _db.collection('upcomingEnrollments').where('studentId', isEqualTo: studentId).get();
    return snap.docs
        .map((doc) => _string(doc.data()['courseId']))
        .whereType<String>()
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
  }

  Future<List<SemesterRegistrationRecord>> _fetchRegistrations(String studentId) async {
    final snap = await _db.collection('registrations').where('studentId', isEqualTo: studentId).get();
    return snap.docs.map((doc) => SemesterRegistrationRecord.fromMap(doc.data(), doc.id)).toList();
  }

  Future<SemesterRegistrationForm?> _fetchActiveForm({
    required int semester,
    required String department,
  }) async {
    final snap = await _db
        .collection('registrationForms')
        .where('semester', isEqualTo: semester)
        .where('active', isEqualTo: true)
        .get();
    if (snap.docs.isEmpty) return null;

    final forms = snap.docs
        .map((doc) => SemesterRegistrationForm.fromMap(doc.data(), doc.id))
        .where((form) => form.department.isEmpty || department.trim().isEmpty || form.department.toLowerCase() == department.trim().toLowerCase())
        .toList();
    if (forms.isEmpty) return null;
    forms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return forms.first;
  }

  Future<Set<String>> _fetchAllowedCourseIdsForSemester(int semester) async {
    final snap = await _db
        .collection('registrationForms')
        .where('semester', isEqualTo: semester)
        .where('active', isEqualTo: true)
        .get();
    final allowed = <String>{};
    for (final doc in snap.docs) {
      final form = SemesterRegistrationForm.fromMap(doc.data(), doc.id);
      allowed.addAll(form.availableCourseIds);
    }
    return allowed;
  }

  Future<Map<String, RegistrationCourseOption>> _fetchCourseMap(List<String> ids) async {
    final uniqueIds = _normalizeIds(ids);
    if (uniqueIds.isEmpty) return {};

    final courses = await _fetchCourseOptions();
    final byId = {for (final course in courses) course.id: course};
    return {
      for (final id in uniqueIds)
        if (byId.containsKey(id)) id: byId[id]!,
    };
  }

  List<String> _normalizeIds(Iterable<String> values) {
    return values.map((value) => value.trim()).where((value) => value.isNotEmpty).toSet().toList();
  }

  bool _matchesDepartment(String courseDepartment, String studentDepartment) {
    if (courseDepartment.trim().isEmpty) return true;
    if (studentDepartment.trim().isEmpty) return true;
    return courseDepartment.trim().toLowerCase() == studentDepartment.trim().toLowerCase();
  }

  Future<void> _deleteRefs(List<DocumentReference<Map<String, dynamic>>> refs) async {
    if (refs.isEmpty) return;

    for (var i = 0; i < refs.length; i += 400) {
      final batch = _db.batch();
      for (final ref in refs.sublist(i, i + 400 > refs.length ? refs.length : i + 400)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  String? _string(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.trim();
    return value.toString().trim();
  }
}

Future<Map<String, String>> fetchUserNamesForRegistration(Iterable<String> userIds) {
  return AdminModuleService.instance.fetchUserNamesById(userIds);
}
