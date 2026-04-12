import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/semester_registration.dart';
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
    final targetSemester = currentSemester + 1;
    final courseOptions = await _fetchCourseOptions();
    final enrollments = await _fetchEnrollmentCourseIds(studentId);
    final upcomingEnrollments = await _fetchUpcomingEnrollmentCourseIds(studentId);
    final registrations = await _fetchRegistrations(studentId);

    final activeRegistration = registrations
        .where((record) => record.targetSemester == targetSemester && (record.status == 'pending' || record.status == 'approved'))
        .fold<SemesterRegistrationRecord?>(null, (previous, record) {
          if (previous == null) return record;
          return record.createdAt.compareTo(previous.createdAt) > 0 ? record : previous;
        });

    final availableCourses = courseOptions
        .where((course) => course.semester == targetSemester && _matchesDepartment(course.department, studentDepartment))
        .where((course) => !enrollments.contains(course.id))
        .where((course) => !upcomingEnrollments.contains(course.id))
        .toList()
      ..sort((a, b) => a.courseCode.toLowerCase().compareTo(b.courseCode.toLowerCase()));

    final backlogCourses = courseOptions
        .where((course) => course.semester > 0 && course.semester < targetSemester && _matchesDepartment(course.department, studentDepartment))
        .where((course) => !enrollments.contains(course.id))
        .where((course) => !upcomingEnrollments.contains(course.id))
        .toList()
      ..sort((a, b) => a.courseCode.toLowerCase().compareTo(b.courseCode.toLowerCase()));

    return SemesterRegistrationContext(
      studentId: studentId,
      studentName: studentName,
      studentEmail: studentEmail,
      currentSemester: currentSemester,
      targetSemester: targetSemester,
      creditLimit: creditLimit,
      availableCourses: availableCourses,
      backlogCourses: backlogCourses,
      enrolledCourseIds: enrollments,
      upcomingCourseIds: upcomingEnrollments,
      activeRegistration: activeRegistration,
    );
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

  Future<String> submitRegistration({
    required String studentId,
    required String studentName,
    required String studentEmail,
    required int currentSemester,
    required int creditLimit,
    required List<String> selectedCourseIds,
    required List<String> backlogCourseIds,
  }) async {
    final targetSemester = currentSemester + 1;
    final normalizedSelected = _normalizeIds(selectedCourseIds);
    final normalizedBacklog = _normalizeIds(backlogCourseIds);

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

    if (backlog.any((course) => course.semester >= targetSemester)) {
      throw Exception('Backlog courses must be from a previous semester.');
    }

    final totalCredits = [
      ...selected,
      ...backlog,
    ].fold<int>(0, (sum, course) => sum + course.credits);
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
    await docRef.set({
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
    });
    return docRef.id;
  }

  Future<void> reviewRegistration({
    required String registrationId,
    required String adminId,
    required bool approve,
    String? rejectionReason,
  }) async {
    await _db.runTransaction((txn) async {
      final regRef = _db.collection('registrations').doc(registrationId);
      final regSnap = await txn.get(regRef);
      if (!regSnap.exists || regSnap.data() == null) {
        throw Exception('Registration request not found.');
      }

      final record = SemesterRegistrationRecord.fromMap(regSnap.data()!, regSnap.id);
      if (record.status != 'pending') {
        throw Exception('This request has already been reviewed.');
      }

      if (!approve && (rejectionReason == null || rejectionReason.trim().isEmpty)) {
        throw Exception('Please provide a rejection reason.');
      }

      if (approve) {
        final courseIds = {...record.selectedCourseIds, ...record.backlogCourseIds}.toList();
        for (final courseId in courseIds) {
          final enrollRef = _db.collection('upcomingEnrollments').doc('upcoming_${record.studentId}_$courseId');
          txn.set(
            enrollRef,
            {
              'studentId': record.studentId,
              'courseId': courseId,
              'semesterType': 'upcoming',
              'currentSemester': record.currentSemester,
              'semester': record.targetSemester,
              'status': 'active',
              'registrationId': record.id,
              'approvedAt': FieldValue.serverTimestamp(),
              'approvedBy': adminId,
            },
            SetOptions(merge: true),
          );
        }
      }

      txn.set(
        regRef,
        {
          'status': approve ? 'approved' : 'rejected',
          'reviewedBy': adminId,
          'reviewedAt': FieldValue.serverTimestamp(),
          if (!approve) 'rejectionReason': rejectionReason?.trim(),
        },
        SetOptions(merge: true),
      );

      txn.set(
        _db.collection('notifications').doc(),
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
    });
  }

  Future<void> resetUpcomingRegistrationCycle() async {
    final registrationsSnap = await _db.collection('registrations').get();
    final upcomingSnap = await _db.collection('upcomingEnrollments').get();

    final registrationRefs = registrationsSnap.docs
        .where((doc) {
          final data = doc.data();
          return data['targetSemester'] != null || data['registrationType'] == 'semester_registration';
        })
        .map((doc) => doc.reference)
        .toList();
    final upcomingRefs = upcomingSnap.docs.map((doc) => doc.reference).toList();

    await _deleteRefs([...registrationRefs, ...upcomingRefs]);
  }

  Future<List<RegistrationCourseOption>> _fetchCourseOptions() async {
    final snap = await _db.collection('courses').get();
    return snap.docs
        .map((doc) => RegistrationCourseOption.fromMap(doc.data(), doc.id))
        .where((course) => course.courseName.trim().isNotEmpty)
        .toList();
  }

  Future<List<String>> _fetchEnrollmentCourseIds(String studentId) async {
    final snap = await _db.collection('enrollments').where('studentId', isEqualTo: studentId).get();
    return snap.docs
        .map((doc) => doc.data()['courseId'] as String?)
        .whereType<String>()
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
  }

  Future<List<String>> _fetchUpcomingEnrollmentCourseIds(String studentId) async {
    final snap = await _db.collection('upcomingEnrollments').where('studentId', isEqualTo: studentId).get();
    return snap.docs
        .map((doc) => doc.data()['courseId'] as String?)
        .whereType<String>()
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
  }

  Future<List<SemesterRegistrationRecord>> _fetchRegistrations(String studentId) async {
    final snap = await _db.collection('registrations').where('studentId', isEqualTo: studentId).get();
    return snap.docs.map((doc) => SemesterRegistrationRecord.fromMap(doc.data(), doc.id)).toList();
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
}

Future<Map<String, String>> fetchUserNamesForRegistration(Iterable<String> userIds) {
  return AdminModuleService.instance.fetchUserNamesById(userIds);
}
